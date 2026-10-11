# Code-retreat kata starter (Copier)

A [Copier](https://copier.readthedocs.io/) template that stamps out a ready-to-test
kata in one command. Python (pytest + uv), JavaScript (`node:test`), or a plain
starter for any other language.

```
code-retreat/                      # all templating-related files live here
├── newkata                        # convenience wrapper around `copier copy`
└── kata-template/                 # the Copier template (its own git repo, tagged)
    ├── copier.yml                 # questions + conditional files + post-gen tasks
    ├── README.md.jinja            # shared, with per-language sections
    ├── .gitignore.jinja
    ├── Makefile.jinja
    ├── {{ _copier_conf.answers_file }}.jinja
    ├── pyproject.toml.jinja                  # Python
    ├── src/{{ python_package }}/__init__.py.jinja
    ├── tests/test_placeholder.py.jinja
    ├── package.json.jinja                    # JavaScript
    ├── src/index.js
    └── tests/placeholder.test.js
```

> `kata-template/` is kept as a **standalone git repo** (with version tags) so
> Copier's `update` feature works and it can be pushed to GitHub on its own.
> The surrounding workspace repo ignores that nested repo.

## 1. Install Copier

```bash
pipx install copier        # or: uv tool install copier
```

## 2. Generate a kata

Interactive:

```bash
./newkata my-kata
```

Non-interactive (great for scripting / a bash alias):

```bash
./newkata my-kata --defaults \
  -d project_name="String Calculator" \
  -d language=python
```

Result:

```
my-kata/
├── .copier-answers.yml   # records answers → enables `copier update`
├── Makefile
├── README.md
├── pyproject.toml
├── src/string_calculator/__init__.py
└── tests/test_placeholder.py
```

Then run the tests:

```bash
cd my-kata
uv run pytest          # Python
node --test            # JavaScript
make test              # generic
```

## 3. What the template demonstrates

| Copier feature | Where |
| --- | --- |
| Prompt types: text, choice, bool | `project_name`, `language`, `use_git` |
| Derived defaults (Jinja) | `project_slug`, `python_package` |
| Conditional **files** | `_exclude` in `copier.yml` |
| Conditional **content** | `{% if language == ... %}` in the `.jinja` files |
| Post-generation **tasks** | `_tasks` → `git init` + first commit |
| Answers file for updates | `_answers_file` / `.copier-answers.yml` |
| Friendly closing message | `_message_after_copy` |

## 4. Updating generated projects

Because the template is a git repo with tags, every generated kata records the
template commit. When you improve the template:

```bash
cd kata-template
git commit -am "add a helper"
git tag v0.3.0

cd ../some-existing-kata
copier update          # three-way merges template changes into your kata
```

Your local edits are preserved; only template-owned changes are merged in.

## 5. Use it from anywhere

Push `kata-template/` to GitHub/GitLab and reference it directly:

```bash
copier copy --trust gh:your-user/kata-template my-kata
```

Or point the wrapper at it in your shell config:

```bash
export KATA_TEMPLATE=gh:your-user/kata-template
alias kata='~/path/to/code-retreat/newkata'
```

## Retreat tips

- **Tag the template** (`v0.1.0`, `v0.2.0`, …) — Copier uses tags for updates.
- Keep **one template per language** if they diverge a lot; the multi-language
  `_exclude` approach is fine while the scaffolds stay small.
- Add a **`git reset --hard && git clean -fd`** alias to instantly rewind a kata
  between sessions instead of re-copying.
- Post-gen tasks need `--trust`. Only trust templates you control.

## Verified in this workspace

- Generated + ran Python (`pytest`: 2 passed) and JavaScript (`node --test`: 2 passed).
- `make test` works for the generic starter.
- `copier update` upgraded a generated project `v0.1.0 → v0.2.0` and merged in
  new code while keeping the existing code intact.
