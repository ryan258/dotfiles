#!/usr/bin/env bash
set -euo pipefail

# gcal.sh - Pure Bash Google Calendar Client
# Uses OAuth 2.0 Device Flow to authenticate without a browser callback or Python.
# Dependencies: curl, jq

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/common.sh"
fi

if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/config.sh"
else
    echo "Error: configuration library not found at $SCRIPT_DIR/lib/config.sh" >&2
    exit 1
fi
if [ -f "$SCRIPT_DIR/lib/date_utils.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/date_utils.sh"
else
    echo "Error: date utilities not found at $SCRIPT_DIR/lib/date_utils.sh" >&2
    exit 1
fi
if [ -f "$SCRIPT_DIR/lib/oauth.sh" ]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/oauth.sh"
else
    echo "Error: OAuth helpers not found at $SCRIPT_DIR/lib/oauth.sh" >&2
    exit 1
fi

CREDS_FILE="${GCAL_CREDS_FILE:?GCAL_CREDS_FILE is not set by config.sh}"
TOKEN_FILE="${GCAL_TOKEN_FILE:?GCAL_TOKEN_FILE is not set by config.sh}"
mkdir -p "$DATA_DIR"

# Delegate to consolidated sanitize_single_line in common.sh
sanitize_line() { sanitize_single_line "$1"; }

# Prevent sourcing
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error: $(basename "$0") should not be sourced." >&2
    return 1
fi

# API Endpoints
AUTH_BASE="https://oauth2.googleapis.com"
API_BASE="https://www.googleapis.com/calendar/v3"
SCOPE="https://www.googleapis.com/auth/calendar"

show_help() {
    echo "Usage: $(basename "$0") {auth|agenda|add|list}"
    echo ""
    echo "Commands:"
    echo "  auth                       Authenticate with Google (Interactive)"
    echo "  agenda [days]              Show agenda for next N days (default: 1)"
    echo "  add \"Event Title\"          Add new event (Quick Add)"
    echo "  list                       List all calendars"
    echo ""
    echo "Security Note: Credentials are stored in $CREDS_FILE (restrict access!)"
}

# --- Auth Functions ---

check_deps() {
    require_cmd "curl" "Install with: brew install curl"
    require_cmd "jq" "Install with: brew install jq"
}

_gcal_curl() {
    curl -sS "$@"
}

load_creds() {
    if [ ! -f "$CREDS_FILE" ]; then
        echo "Error: Credentials not found." >&2
        echo "Please run: $(basename "$0") auth" >&2
        exit 1
    fi
    CLIENT_ID=$(jq -r '.client_id' "$CREDS_FILE")
    CLIENT_SECRET=$(jq -r '.client_secret' "$CREDS_FILE")
    REFRESH_TOKEN=$(jq -r '.refresh_token // empty' "$CREDS_FILE")
}

cmd_auth() {
    check_deps
    echo "=== Google Calendar Authentication (Device Flow) ==="
    echo "You need a Google Cloud Project with 'Calendar API' enabled."
    echo "Create OAuth credentials for 'TV and Limited Input devices'."
    echo ""
    read -rp "Enter Client ID: " CLIENT_ID
    read -rp "Enter Client Secret: " CLIENT_SECRET
    CLIENT_ID=$(sanitize_line "$CLIENT_ID")
    CLIENT_SECRET=$(sanitize_line "$CLIENT_SECRET")
    
    # 1. Request Device Code
    RESPONSE=$(curl -s -d "client_id=$CLIENT_ID" \
                       -d "scope=$SCOPE" \
                       "$AUTH_BASE/device/code")
    
    DEVICE_CODE=$(echo "$RESPONSE" | jq -r '.device_code')
    USER_CODE=$(echo "$RESPONSE" | jq -r '.user_code')
    VERIFICATION_URL=$(echo "$RESPONSE" | jq -r '.verification_url')
    INTERVAL=$(echo "$RESPONSE" | jq -r '.interval')
    
    if [ "$DEVICE_CODE" == "null" ]; then
        echo "Error requesting device code:" >&2
        echo "$RESPONSE" >&2
        exit 1
    fi
    
    echo ""
    echo "👉 Action Required:"
    echo "1. Go to: $VERIFICATION_URL"
    echo "2. Enter code: $USER_CODE"
    echo ""
    echo "Waiting for authorization..."
    
    # 2. Poll for Token
    while true; do
        sleep "${INTERVAL:-5}"
        TOKEN_RES=$(curl -s -d "client_id=$CLIENT_ID" \
                            -d "client_secret=$CLIENT_SECRET" \
                            -d "device_code=$DEVICE_CODE" \
                            -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
                            "$AUTH_BASE/token")
        
        ERROR=$(echo "$TOKEN_RES" | jq -r '.error // empty')
        
        if [ -z "$ERROR" ]; then
            # Success!
            REFRESH_TOKEN="$(oauth_extract_refresh_token "$TOKEN_RES")"
            ACCESS_TOKEN="$(oauth_extract_access_token "$TOKEN_RES")"
            EXPIRES_IN="$(oauth_extract_expires_in "$TOKEN_RES" 3600)"

            oauth_write_refresh_credentials "$CREDS_FILE" "$CLIENT_ID" "$CLIENT_SECRET" "$REFRESH_TOKEN" || {
                echo "Error: Failed to write Calendar credentials to $CREDS_FILE" >&2
                exit 1
            }
            oauth_write_access_token_cache "$TOKEN_FILE" "$ACCESS_TOKEN" "$EXPIRES_IN" || {
                echo "Error: Failed to write Calendar token cache to $TOKEN_FILE" >&2
                exit 1
            }
               
            echo "✅ Authentication successful! Credentials saved."
            break
        elif [ "$ERROR" == "authorization_pending" ]; then
            echo -n "."
        elif [ "$ERROR" == "slow_down" ]; then
            INTERVAL=$((INTERVAL + 5))
            echo -n "."
        else
            echo ""
            echo "Error: $ERROR" >&2
            exit 1
        fi
    done
}

get_access_token() {
    # Check cache
    if [ -f "$TOKEN_FILE" ]; then
        EXPIRY=$(jq -r '.expiry' "$TOKEN_FILE")
        NOW=$(date_epoch_now)
        if [ "$NOW" -lt "$EXPIRY" ]; then
            jq -r '.access_token' "$TOKEN_FILE"
            return
        fi
    fi
    
    # Refresh Token
    load_creds
    if [ -z "${REFRESH_TOKEN:-}" ]; then
        echo "Error: No refresh token. Run auth." >&2
        exit 1
    fi
    
    REFRESH_RES="$(oauth_refresh_token_request "$AUTH_BASE/token" "$CLIENT_ID" "$CLIENT_SECRET" "$REFRESH_TOKEN" _gcal_curl)"
    
    ACCESS_TOKEN="$(oauth_extract_access_token "$REFRESH_RES")"
    EXPIRES_IN="$(oauth_extract_expires_in "$REFRESH_RES" 3600)"
    
    if [[ -z "$ACCESS_TOKEN" ]]; then
        echo "$(oauth_format_error_message "$REFRESH_RES" "Google Calendar token refresh failed" "Google Calendar token refresh failed: response did not contain access_token")" >&2
        exit 1
    fi
    
    oauth_write_access_token_cache "$TOKEN_FILE" "$ACCESS_TOKEN" "$EXPIRES_IN" || {
        echo "Error: Failed to write Calendar token cache to $TOKEN_FILE" >&2
        exit 1
    }
       
    echo "$ACCESS_TOKEN"
}

# --- API Commands ---

call_api() {
    METHOD="$1"
    ENDPOINT="$2"
    shift 2 #(Rest are args usually data)
    
    TOKEN=$(get_access_token)
    
    # -w "\n%{http_code}" appends status code to output for easier checking
    RESPONSE_RAW=$(curl -s -w "\n%{http_code}" -X "$METHOD" \
         -H "Authorization: Bearer $TOKEN" \
         -H "Content-Type: application/json" \
         "$@" \
         "$API_BASE/$ENDPOINT")

    # Extract Body (all lines except last) and Status Code (last line)
    # Using sed to reliably separate them
    HTTP_CODE=$(echo "$RESPONSE_RAW" | tail -n1)
    BODY=$(echo "$RESPONSE_RAW" | sed '$d')

    if [[ "$HTTP_CODE" -ge 400 ]]; then
        echo "API Error (HTTP $HTTP_CODE):" >&2
        echo "$BODY" >&2
        return 1
    fi

    echo "$BODY"
}

case "${1:-agenda}" in
    auth)
        cmd_auth
        ;;
        
    list)
        check_deps
        RESPONSE=$(call_api GET "users/me/calendarList")
        if ! echo "$RESPONSE" | jq -e . >/dev/null 2>&1; then
             echo "Error from Google API:"
             echo "$RESPONSE"
             exit 1
        fi
        echo "=== My Calendars ==="
        echo "$RESPONSE" | jq -r '.items[] | "• " + .summary + " (" + (.accessRole) + ")"'
        ;;
        
    agenda)
        check_deps
        DAYS="${2:-1}"
        
        if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
            echo "Error: days must be a number" >&2
            exit 1
        fi
        
        # Calculate timeMin (Now) and timeMax (Now + N days)
        # RFC3339 format: YYYY-MM-DDThh:mm:ssZ
        TIME_MIN=$(date_now_utc "%Y-%m-%dT%H:%M:%SZ")
        TIME_MAX=$(date_shift_days_utc "$DAYS" "%Y-%m-%dT%H:%M:%SZ")
        
        # Fetch Events (singleEvents=true expands recurring)
        RESPONSE=$(call_api GET "calendars/primary/events?singleEvents=true&orderBy=startTime&timeMin=$TIME_MIN&timeMax=$TIME_MAX")
        
        if ! echo "$RESPONSE" | jq -e . >/dev/null 2>&1; then
             echo "Error from Google API:"
             echo "$RESPONSE"
             exit 1
        fi

        echo "📅 Agenda for next $DAYS days:"
        echo "------------------------------------------------"
        
        ITEMS=$(echo "$RESPONSE" | jq -r '.items')
        if [ "$ITEMS" == "null" ] || [ "$ITEMS" == "[]" ]; then
             echo "  (No events found)"
        else
             # Parse and format: HH:MM Event Title
             # Handle 'dateTime' (specific time) vs 'date' (all day)
             echo "$RESPONSE" | jq -r '.items[] | 
                if .start.dateTime then 
                    (.start.dateTime | split("T")[1] | sub(":00Z$"; "") | sub(":[0-9]{2}-[0-9]{2}:[0-9]{2}$"; "") | .[0:5]) + "  " + .summary 
                else 
                    "All Day  " + .summary 
                end' | sed 's/^/  /'
        fi
        ;;
        
    add)
        check_deps
        shift
        EVENT_TEXT=$(sanitize_line "${*:-}")
        if [ -z "$EVENT_TEXT" ]; then
            echo "Usage: calendar add \"Meeting with Bob tomorrow at 2pm\""
            exit 1
        fi
        
        # Quick Add URL encoding
        # Simple jq url encode trick
        ENCODED=$(jq -rn --arg x "$EVENT_TEXT" '$x|@uri')
        
        RESPONSE=$(call_api POST "calendars/primary/events/quickAdd?text=$ENCODED")
        
        STATUS=$(echo "$RESPONSE" | jq -r '.status')
        LINK=$(echo "$RESPONSE" | jq -r '.htmlLink')
        
        if [ "$STATUS" == "confirmed" ]; then
            echo "✅ Added: $EVENT_TEXT"
            echo "   Link: $LINK"
        else
            echo "Error adding event:"
            echo "$RESPONSE"
        fi
        ;;
        
    help|--help|-h)
        show_help
        ;;
        
    *)
        show_help
        exit 1
        ;;
esac
