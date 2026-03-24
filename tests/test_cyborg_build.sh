#!/usr/bin/env bats
# test_cyborg_build.sh - Focused regression tests for Cyborg's build pipeline.

@test "cyborg build python verify setup creates an isolated env and installs dev requirements" {
    run python3 -c "
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

with tempfile.TemporaryDirectory() as d:
    project_dir = Path(d)
    (project_dir / 'requirements.txt').write_text('requests>=2.0\\n', encoding='utf-8')
    prepared = cyborg_build._prepare_python_verify_commands(project_dir)
    assert prepared is not None
    verify_env, install_cmd, test_cmd = prepared

    assert '-m pip install -q --upgrade pip' in install_cmd
    assert '-m pip install -q -r requirements.txt' in install_cmd
    assert 'requirements-dev.txt' in install_cmd
    assert '/cyborg-verify-' in install_cmd
    assert '/cyborg-verify-' in test_cmd
    assert test_cmd.endswith(' -m pytest -x')
    verify_env.cleanup()

print('python isolated verify setup ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"python isolated verify setup ok"* ]]
}

@test "cyborg build install fixes use the install-specific prompt and manifest priority list" {
    run python3 -c "
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

class FakeAI:
    def __init__(self):
        self.calls = []

    def chat_json(self, prompt, user_msg, temperature=0.0):
        self.calls.append((prompt, user_msg, temperature))
        return {'files': {'requirements.txt': 'requests>=2.32.0\\n'}}

with tempfile.TemporaryDirectory() as d:
    project_dir = Path(d)
    (project_dir / 'requirements.txt').write_text('axe-core-python>=2.0.0\\n', encoding='utf-8')
    (project_dir / 'requirements-dev.txt').write_text('pytest>=8.0.0\\n', encoding='utf-8')
    (project_dir / 'app.py').write_text('print(\\'hello\\')\\n', encoding='utf-8')

    ai = FakeAI()
    applied = cyborg_build._apply_ai_fix(
        project_dir,
        'wcag audit cli',
        'install',
        'python -m pip install -r requirements.txt',
        'ERROR: No matching distribution found for axe-core-python>=2.0.0',
        ai,
    )

    assert applied is True
    assert len(ai.calls) == 1
    prompt, user_msg, _ = ai.calls[0]
    assert prompt == cyborg_build.MORPHLING_INSTALL_FIX_PROMPT
    assert 'Priority files for install fixes' in user_msg
    assert 'requirements.txt' in user_msg
    assert 'requirements-dev.txt' in user_msg
    assert 'app.py' in user_msg

print('install prompt regression ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"install prompt regression ok"* ]]
}

@test "cyborg build fix snapshots exclude node_modules and lockfiles" {
    run python3 -c "
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

class FakeAI:
    def __init__(self):
        self.calls = []

    def chat_json(self, prompt, user_msg, temperature=0.0):
        self.calls.append((prompt, user_msg, temperature))
        return {'files': {'src/index.js': 'console.log(\\'fixed\\')\\n'}}

with tempfile.TemporaryDirectory() as d:
    project_dir = Path(d)
    (project_dir / 'src').mkdir(parents=True, exist_ok=True)
    (project_dir / 'node_modules' / 'left-pad').mkdir(parents=True, exist_ok=True)
    (project_dir / 'src' / 'index.js').write_text('console.log(\\'hi\\')\\n', encoding='utf-8')
    (project_dir / 'package-lock.json').write_text('{\\n  \\\"name\\\": \\\"demo\\\"\\n}\\n', encoding='utf-8')
    (project_dir / 'node_modules' / 'left-pad' / 'index.js').write_text('x' * 20000, encoding='utf-8')

    ai = FakeAI()
    applied = cyborg_build._apply_ai_fix(
        project_dir,
        'wcag auditor cli',
        'test',
        'npm test',
        'Example test failure',
        ai,
    )

    assert applied is True
    assert len(ai.calls) == 1
    _, user_msg, _ = ai.calls[0]
    assert 'src/index.js' in user_msg
    assert 'node_modules' not in user_msg
    assert 'package-lock.json' not in user_msg

print('snapshot pruning ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"snapshot pruning ok"* ]]
}

@test "cyborg build normalizes swapped scaffold file mappings" {
    run python3 -c "
import sys

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

normalized, swapped, malformed = cyborg_build._normalize_scaffold_files({
    'README.md': '# Title\\n',
    'import json\\nprint(\\'bad path\\')\\n': 'wcag_auditor/reporter.py',
})

assert normalized['README.md'] == '# Title\\n'
assert normalized['wcag_auditor/reporter.py'].startswith('import json')
assert swapped == 1
assert malformed == 0

print('scaffold normalization ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"scaffold normalization ok"* ]]
}

@test "cyborg chat_json extracts fenced JSON objects" {
    run python3 -c "
import sys

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
from cyborg_agent import OpenRouterClient

client = OpenRouterClient()
fence = chr(96) * 3
client._request = lambda payload: {
    'choices': [
        {
            'message': {
                'content': f\"{fence}json\\n{{\\\"name\\\": \\\"demo\\\", \\\"files\\\": {{}}}}\\n{fence}\"
            }
        }
    ]
}

data = client.chat_json('system', 'user')
assert data['name'] == 'demo'
assert data['files'] == {}

print('fenced json parse ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"fenced json parse ok"* ]]
}

@test "cyborg chat_json fails fast on stalled ai requests" {
    run python3 -c "
import sys
import threading
import time
import unittest.mock

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
from cyborg_agent import OpenRouterClient

client = OpenRouterClient()
client.timeout_seconds = 1
release = threading.Event()

def fake_perform_request(payload):
    release.wait(5)
    return {'choices': [{'message': {'content': '{\\\"ok\\\": true}'}}]}

with unittest.mock.patch.object(client, '_perform_request', side_effect=fake_perform_request):
    started = time.monotonic()
    try:
        client.chat_json('system', 'user')
        raise AssertionError('expected timeout')
    except RuntimeError as exc:
        elapsed = time.monotonic() - started
        assert 'timed out after 1 seconds' in str(exc), str(exc)
        assert elapsed < 2.5, elapsed
    finally:
        release.set()

print('ai timeout guard ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"ai timeout guard ok"* ]]
}

@test "cyborg build retries install failures across the full verification budget" {
    run python3 -c "
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

with tempfile.TemporaryDirectory() as d:
    project_dir = Path(d)
    (project_dir / 'requirements.txt').write_text('requests>=2.0\\n', encoding='utf-8')

    install_attempts = []
    fix_phases = []

    def fake_run_command_result(argv, cwd=None, env=None, timeout=None):
        if argv[:3] == [sys.executable, '-m', 'venv']:
            venv_dir = Path(argv[3])
            python_bin = venv_dir / 'bin' / 'python'
            python_bin.parent.mkdir(parents=True, exist_ok=True)
            python_bin.write_text('#!/usr/bin/env python3\\n', encoding='utf-8')
            return 0, '', ''

        command = argv[-1]
        if '-m pip install' in command:
            install_attempts.append(command)
            if len(install_attempts) < 3:
                return 1, '', 'ERROR: No matching distribution found'
            return 0, '', ''
        if '-m pytest -x' in command:
            return 0, '', ''
        raise AssertionError(f'unexpected command: {command}')

    def fake_apply_ai_fix(project_dir, idea, phase, command, error_output, ai_client):
        fix_phases.append((phase, command, error_output))
        return True

    old_run = cyborg_build.run_command_result
    old_fix = cyborg_build._apply_ai_fix
    try:
        cyborg_build.run_command_result = fake_run_command_result
        cyborg_build._apply_ai_fix = fake_apply_ai_fix
        cyborg_build._verify_and_fix_scaffold(project_dir, 'wcag audit cli', object())
    finally:
        cyborg_build.run_command_result = old_run
        cyborg_build._apply_ai_fix = old_fix

    assert len(install_attempts) == 3, install_attempts
    assert [phase for phase, _, _ in fix_phases] == ['install', 'install'], fix_phases

print('install retry regression ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"install retry regression ok"* ]]
}

@test "cyborg build detects extension projects from manifest json" {
    run python3 -c "
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

with tempfile.TemporaryDirectory() as d:
    project_dir = Path(d)
    (project_dir / 'manifest.json').write_text('{\"manifest_version\":3,\"name\":\"Demo\",\"version\":\"0.1.0\"}\\n', encoding='utf-8')
    recipe = cyborg_build._detect_verify_recipe(project_dir)
    assert recipe == ('extension', None, 'extension verification'), recipe

print('extension recipe ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"extension recipe ok"* ]]
}

@test "cyborg build extension verification validates manifest references and js syntax" {
    run python3 -c "
import json
import sys
import tempfile
import unittest.mock
from pathlib import Path

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

with tempfile.TemporaryDirectory() as d:
    project_dir = Path(d)
    manifest = {
        'manifest_version': 3,
        'name': 'Demo',
        'version': '0.1.0',
        'background': {'service_worker': 'background.js'},
        'action': {'default_popup': 'popup.html'},
        'content_scripts': [{'matches': ['<all_urls>'], 'js': ['content.js'], 'css': ['overlay.css']}],
    }
    (project_dir / 'manifest.json').write_text(json.dumps(manifest), encoding='utf-8')
    (project_dir / 'background.js').write_text('const x = 1;\\n', encoding='utf-8')
    (project_dir / 'content.js').write_text('const y = 2;\\n', encoding='utf-8')
    (project_dir / 'popup.html').write_text('<!doctype html><html></html>\\n', encoding='utf-8')
    (project_dir / 'overlay.css').write_text('body { color: red; }\\n', encoding='utf-8')

    checked = []

    def fake_run_command_result(argv, cwd=None, env=None, timeout=None):
        checked.append(argv)
        return 0, '', ''

    with unittest.mock.patch.object(cyborg_build.shutil, 'which', return_value='/usr/bin/node'), \
         unittest.mock.patch.object(cyborg_build, 'run_command_result', side_effect=fake_run_command_result):
        exit_code, stdout, stderr = cyborg_build._verify_extension_project(project_dir)

    assert exit_code == 0, stderr
    assert 'Extension verification checks passed.' in stdout
    assert any(argv[:2] == ['/usr/bin/node', '--check'] for argv in checked), checked

    (project_dir / 'content.js').unlink()
    with unittest.mock.patch.object(cyborg_build.shutil, 'which', return_value=None):
        exit_code, stdout, stderr = cyborg_build._verify_extension_project(project_dir)

    assert exit_code == 1
    assert \"manifest.json references missing file 'content.js'.\" in stderr

print('extension verification ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"extension verification ok"* ]]
}

@test "cyborg build prompts require verified dependency APIs and consistent semantics" {
    run python3 -c "
import sys

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

assert 'Only call third-party APIs whose public entry points you can name concretely' in cyborg_build.MORPHLING_BUILD_PROMPT
assert 'keep CLI help text, docstrings, implementation, and tests consistent' in cyborg_build.MORPHLING_BUILD_PROMPT
assert 'Tests must be deterministic and offline' in cyborg_build.MORPHLING_BUILD_PROMPT
assert 'Do not keep tests coupled to guessed third-party symbols' in cyborg_build.MORPHLING_TEST_FIX_PROMPT
assert 'use the verified installed module surface from the project instead of guessing' in cyborg_build.MORPHLING_TEST_FIX_PROMPT
assert 'Replace placeholder \"expected to fail\" assertions and live-network tests' in cyborg_build.MORPHLING_TEST_FIX_PROMPT

print('prompt guardrails ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"prompt guardrails ok"* ]]
}

@test "cyborg build test fixes include installed module surfaces for missing attrs" {
    run python3 -c "
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

class FakeAI:
    def __init__(self):
        self.calls = []

    def chat_json(self, prompt, user_msg, temperature=0.0):
        self.calls.append((prompt, user_msg, temperature))
        return {'files': {'app.py': 'print(\\'fixed\\')\\n'}}

with tempfile.TemporaryDirectory() as d:
    project_dir = Path(d)
    (project_dir / 'app.py').write_text('print(\\'broken\\')\\n', encoding='utf-8')

    def fake_run_command_result(argv, cwd=None, env=None, timeout=None):
        assert argv[0] == '/tmp/python', argv
        assert argv[1] == '-c', argv
        assert argv[3] == 'axe_core_python', argv
        payload = {
            'module': 'axe_core_python',
            'attrs': [],
            'submodules': ['base', 'selenium', 'sync_playwright'],
        }
        return 0, json.dumps(payload), ''

    ai = FakeAI()
    old_run = cyborg_build.run_command_result
    try:
        cyborg_build.run_command_result = fake_run_command_result
        applied = cyborg_build._apply_ai_fix(
            project_dir,
            'wcag audit cli',
            'test',
            '/tmp/python -m pytest -x',
            \"AttributeError: <module 'axe_core_python' from '/tmp/pkg'> does not have the attribute 'get_page_analysis'\",
            ai,
        )
    finally:
        cyborg_build.run_command_result = old_run

    assert applied is True
    assert len(ai.calls) == 1
    _, user_msg, _ = ai.calls[0]
    assert 'Verified installed Python module surfaces' in user_msg
    assert 'sync_playwright' in user_msg

print('module surface context ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"module surface context ok"* ]]
}

@test "cyborg build retries empty scaffolds before succeeding" {
    run python3 -c "
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

class FakeAI:
    def __init__(self):
        self.calls = 0

    def chat_json(self, prompt, user_msg, temperature=0.0, max_tokens=None):
        self.calls += 1
        if self.calls == 1:
            return {
                'name': 'wcag-audit-cli',
                'description': 'bad scaffold',
                'files': {},
            }
        return {
            'name': 'wcag-audit-cli',
            'description': 'good scaffold',
            'files': {
                'README.md': '# Demo\\n',
                'app.py': 'print(\\'ok\\')\\n',
            },
        }

with tempfile.TemporaryDirectory() as d:
    projects_dir = Path(d)
    ai = FakeAI()

    old_run = cyborg_build.run_command
    old_verify = cyborg_build._verify_and_fix_scaffold
    try:
        cyborg_build.run_command = lambda *args, **kwargs: 0
        cyborg_build._verify_and_fix_scaffold = lambda *args, **kwargs: None
        project_dir = cyborg_build.build_project_from_idea(
            'wcag audit cli',
            ai,
            projects_dir=projects_dir,
            assume_yes=True,
            interactive=False,
        )
    finally:
        cyborg_build.run_command = old_run
        cyborg_build._verify_and_fix_scaffold = old_verify

    assert ai.calls == 2
    assert project_dir.name == 'wcag-audit-cli'
    assert (project_dir / 'README.md').exists()
    assert (project_dir / 'app.py').exists()

print('scaffold retry ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"scaffold retry ok"* ]]
}

@test "cyborg auto build keeps staged repo edits unapplied after verification even with --yes" {
    run python3 -c "
import io
import sys
from contextlib import redirect_stdout

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_agent

class DummyState:
    def __init__(self):
        self.session_id = 'session-123'
        self.repo_path = '/tmp/generated-repo'
        self.blog_root = '/tmp/blog-root'
        self.article_text = ''
        self.scan_summary = {'root': '/tmp/generated-repo'}
        self.code_improvement_plan = {'items': [{'id': 'improvement-1'}]}
        self.pending_repo_edits = []
        self.gitnexus_skip = False
        self.link_recommendations = []

class DummyGitNexusCLI:
    available = False

class DummyAgent:
    def __init__(self):
        self.state = DummyState()
        self.gitnexus_cli = DummyGitNexusCLI()
        self.messages = []
        self.applied = []

    def assistant_say(self, message):
        self.messages.append(message)

    def save(self):
        return None

    def auto_prepare_repo_context(self):
        return None

    def _gitnexus_decision_pending(self):
        return False

    def build_code_improvement_plan(self):
        return None

    def stage_code_improvement(self):
        self.state.pending_repo_edits = [{'path': 'wcag_audit_cli/audit.py'}]

    def status_lines(self):
        return ['pending build follow-up']

    def apply_changes(self, target, assume_yes=False):
        self.applied.append((target, assume_yes))

agent = DummyAgent()
stdout = io.StringIO()
with redirect_stdout(stdout):
    result = cyborg_agent.run_autopilot(
        agent,
        assume_yes=True,
        build_mode=True,
    )

assert result == 0
assert agent.applied == []
assert any('verified state' in message for message in agent.messages), agent.messages

print('build autopilot leaves edits staged ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"build autopilot leaves edits staged ok"* ]]
}

@test "market github search uses token file and does not leak token in auth errors" {
    run python3 -c "
import sys
import tempfile
import unittest.mock
import urllib.error
from pathlib import Path

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

with tempfile.TemporaryDirectory() as d:
    home = Path(d)
    token_file = home / '.github_token'
    token_file.write_text('super-secret-token\\n', encoding='utf-8')
    captured = {}

    def fake_urlopen(req, timeout=None):
        captured['auth'] = req.get_header('Authorization')
        raise urllib.error.HTTPError(req.full_url, 401, 'Unauthorized', hdrs=None, fp=None)

    with unittest.mock.patch.object(cyborg_build.Path, 'home', return_value=home), \
         unittest.mock.patch.dict(cyborg_build.os.environ, {'GITHUB_TOKEN': '', 'GH_TOKEN': '', 'GITHUB_TOKEN_FILE': '', 'GITHUB_TOKEN_FALLBACK': '', 'DATA_DIR': ''}, clear=False), \
         unittest.mock.patch.object(cyborg_build.urllib.request, 'urlopen', side_effect=fake_urlopen):
        cyborg_build.DEFAULT_GITHUB_TOKEN_FILE = cyborg_build.Path.home() / '.github_token'
        cyborg_build.DEFAULT_DATA_DIR = cyborg_build.Path.home() / '.config' / 'dotfiles-data'
        results = cyborg_build._search_github('wcag audit cli')

    assert results == []
    assert captured['auth'] == 'token super-secret-token'
    note = cyborg_build._MARKET_SEARCH_NOTES['github']
    assert 'authentication rejected' in note
    assert 'super-secret-token' not in note

print('github token fallback ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"github token fallback ok"* ]]
}

@test "market validation prints source specific search notes instead of generic api warning" {
    run python3 -c "
import io
import sys
import unittest.mock
from contextlib import redirect_stdout

sys.path.insert(0, '$BATS_TEST_DIRNAME/../scripts')
import cyborg_build

class FakeAI:
    enabled = True
    def chat_json(self, *a, **kw):
        raise AssertionError('AI should not be called when search results are empty')

def fake_search_github(query):
    cyborg_build._MARKET_SEARCH_NOTES['github'] = 'GitHub search failed: authentication rejected. Check GITHUB_TOKEN, GH_TOKEN, or the configured token file.'
    return []

def fake_search_npm(query):
    cyborg_build._MARKET_SEARCH_NOTES['npm'] = 'npm search failed: network unavailable.'
    return []

buf = io.StringIO()
with unittest.mock.patch.object(cyborg_build, '_search_github', side_effect=fake_search_github), \
     unittest.mock.patch.object(cyborg_build, '_search_npm', side_effect=fake_search_npm), \
     redirect_stdout(buf):
    result = cyborg_build.validate_market('test idea', FakeAI(), assume_yes=True, interactive=False)

text = buf.getvalue()
assert result is True
assert 'GitHub search failed: authentication rejected' in text
assert 'npm search failed: network unavailable.' in text
assert 'APIs may be unreachable' not in text

print('market search status notes ok')
"

    [ "$status" -eq 0 ]
    [[ "$output" == *"market search status notes ok"* ]]
}
