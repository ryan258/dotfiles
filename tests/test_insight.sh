#!/usr/bin/env bats

load "$BATS_TEST_DIRNAME/helpers/test_helpers.sh"
load "$BATS_TEST_DIRNAME/helpers/assertions.sh"

setup() {
    setup_test_environment
    INSIGHT_SCRIPT="$BATS_TEST_DIRNAME/../scripts/insight.sh"
}

teardown() {
    teardown_test_environment
}

@test "insight new creates a hypothesis record" {
    run bash "$INSIGHT_SCRIPT" new "Blue light exposure after 9pm worsens sleep latency" --domain sleep --novelty 4 --prior 0.45
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Created hypothesis: HYP-" ]]

    assert_file_exists "$DOTFILES_DATA_DIR/insight_hypotheses.txt"
    assert_file_contains "$DOTFILES_DATA_DIR/insight_hypotheses.txt" "|sleep|"
    assert_file_contains "$DOTFILES_DATA_DIR/insight_hypotheses.txt" "|OPEN|0.45|4|"
}

@test "insight lifecycle can produce SUPPORTED verdict when all gates pass" {
    run bash "$INSIGHT_SCRIPT" new "Morning walk improves focus scores" --domain cognition --novelty 4 --prior 0.40
    [ "$status" -eq 0 ]
    hyp_id=$(echo "$output" | awk '/Created hypothesis:/ {print $3}')
    [ -n "$hyp_id" ]

    run bash "$INSIGHT_SCRIPT" test-plan "$hyp_id" --prediction "No meaningful focus improvement" --fail-criterion "No improvement after 10 days"
    [ "$status" -eq 0 ]
    test_id=$(echo "$output" | awk '/Created disconfirming test:/ {print $4}')
    [ -n "$test_id" ]

    run bash "$INSIGHT_SCRIPT" test-result "$test_id" --status attempted --result "Test run completed; observed positive trend"
    [ "$status" -eq 0 ]

    run bash "$INSIGHT_SCRIPT" evidence add "$hyp_id" --direction for --strength 4 --source "journal://focus-log" --provenance "journal"
    [ "$status" -eq 0 ]
    run bash "$INSIGHT_SCRIPT" evidence add "$hyp_id" --direction for --strength 3 --source "study://sample-paper" --provenance "paper"
    [ "$status" -eq 0 ]

    run bash "$INSIGHT_SCRIPT" verdict "$hyp_id" --verdict supported --confidence 0.72 --counterargument "Novelty effect inflated scores" --response "Scores remained stable after day seven"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Verdict for $hyp_id: SUPPORTED" ]]

    assert_file_contains "$DOTFILES_DATA_DIR/insight_verdicts.txt" "$hyp_id"
    assert_file_contains "$DOTFILES_DATA_DIR/insight_verdicts.txt" "|SUPPORTED|0.72|"
    assert_file_contains "$DOTFILES_DATA_DIR/insight_hypotheses.txt" "|SUPPORTED|0.40|4|"
}

@test "supported verdict is downgraded when falsification gates fail" {
    run bash "$INSIGHT_SCRIPT" new "Ambient music always improves coding throughput" --domain productivity --novelty 3 --prior 0.50
    [ "$status" -eq 0 ]
    hyp_id=$(echo "$output" | awk '/Created hypothesis:/ {print $3}')
    [ -n "$hyp_id" ]

    run bash "$INSIGHT_SCRIPT" evidence add "$hyp_id" --direction for --strength 2 --source "journal://single-note" --provenance "journal"
    [ "$status" -eq 0 ]

    run bash "$INSIGHT_SCRIPT" verdict "$hyp_id" --verdict supported --confidence 0.50
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Verdict for $hyp_id: INCONCLUSIVE" ]]
    [[ "$output" =~ "Support gates not met" ]]

    assert_file_contains "$DOTFILES_DATA_DIR/insight_verdicts.txt" "|INCONCLUSIVE|0.50|"
}

@test "weekly low-spoons summary prints KPI counters" {
    run bash "$INSIGHT_SCRIPT" new "Protein-heavy breakfast improves afternoon energy" --domain health --novelty 4 --prior 0.35
    [ "$status" -eq 0 ]
    hyp_id_1=$(echo "$output" | awk '/Created hypothesis:/ {print $3}')

    run bash "$INSIGHT_SCRIPT" test-plan "$hyp_id_1"
    [ "$status" -eq 0 ]
    test_id_1=$(echo "$output" | awk '/Created disconfirming test:/ {print $4}')
    run bash "$INSIGHT_SCRIPT" test-result "$test_id_1" --status attempted --result "Ran one-week check with energy logs"
    [ "$status" -eq 0 ]

    run bash "$INSIGHT_SCRIPT" evidence add "$hyp_id_1" --direction for --strength 4 --source "journal://energy-series"
    [ "$status" -eq 0 ]
    run bash "$INSIGHT_SCRIPT" evidence add "$hyp_id_1" --direction for --strength 3 --source "study://diet-sleep-paper"
    [ "$status" -eq 0 ]
    run bash "$INSIGHT_SCRIPT" verdict "$hyp_id_1" --confidence 0.70 --counterargument "sleep quality was the real driver" --response "controlled for sleep score in notes"
    [ "$status" -eq 0 ]

    run bash "$INSIGHT_SCRIPT" new "Late meetings improve deep work output" --domain work --novelty 2 --prior 0.60
    [ "$status" -eq 0 ]
    hyp_id_2=$(echo "$output" | awk '/Created hypothesis:/ {print $3}')
    run bash "$INSIGHT_SCRIPT" verdict "$hyp_id_2" --verdict falsified --confidence 0.30 --why "Observed repeated productivity declines"
    [ "$status" -eq 0 ]

    run bash "$INSIGHT_SCRIPT" weekly --low-spoons
    [ "$status" -eq 0 ]
    [[ "$output" =~ "generated=2" ]]
    [[ "$output" =~ "killed=1" ]]
}
