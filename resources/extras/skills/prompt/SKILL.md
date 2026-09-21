---
name: prompt
description: Generates a structured, context-rich agent handoff prompt file with automated post-task cleanup instructions. Trigger with /prompt <task description>.
---

# /prompt Skill: Agent Handoff Prompt Generator

Generates high-quality, structured handoff prompt files (`AGENT_PROMPT_<TASK_NAME>.txt`) in the project root for subsequent AI coding agents (such as Antigravity CLI or Claude Code). Every generated prompt equips the agent with complete context, clear requirements, clickable file targets, rigorous verification commands, and a mandatory self-cleanup directive.

---

## Invocation Modes

- `/prompt <task description>`: Formulate a handoff prompt for the specified task immediately.
- `/prompt`: If invoked with empty or ambiguous arguments, interview the user to clarify:
  1. What is the objective and desired outcome?
  2. What are the key architectural decisions, constraints, or guidelines?
  3. Which files and components are targeted?
  4. What commands verify that the task is complete?

---

## Agent Execution Workflow

When this skill is invoked, execute the following steps:

### 1. Gather Repository & Environment Context
Before drafting the prompt, inspect the local environment to provide grounding:
- **Git Context**: Current branch (`git branch --show-current`), recent commits (`git log -n 5 --oneline`), and modified/untracked files (`git status -s`).
- **Relevant Files**: Inspect files related to the task, architecture docs (e.g. `ARCHITECTURE.md`), conventions (`check_conventions.sh`, linter rules), or existing implementations.
- **Verification Commands**: Identify existing test runners, `justfile` recipes, or check scripts (`just lint`, `just check-install`, etc.).

### 2. Determine the Output File Name
- Derive an uppercase, snake_case filename based on the task topic.
- Format: `AGENT_PROMPT_<TASK_NAME>.txt` (e.g., `AGENT_PROMPT_DATABASE_MIGRATION.txt`, `AGENT_PROMPT_STATUSLINE_OPENCODE.txt`, `AGENT_PROMPT_AUTH_REFACTOR.txt`).
- Target Location: The root directory of the active workspace.

### 3. Draft the Prompt File Content
The generated file must adhere strictly to the following sections:

1. **Title & Single-Sentence Objective**:
   - Concise summary of the goal.
2. **Context & Background**:
   - Current git branch, recent commits, motivation, related PRs/issues, and system architecture context.
3. **Requirements & Specifications**:
   - Exhaustive bullet points covering functional behavior, edge cases, error handling, output formatting, and UX/CLI expectations.
4. **File Targets & Conventions**:
   - Explicit clickable markdown links to affected files (`[filename](file:///path/to/file)` or repo-relative paths).
   - Relevant project conventions (e.g., POSIX bash, jq, zero unnecessary subshells/forks, `colours.sh`, `next_steps.sh`, idempotency, backups on update).
5. **Verification & Test Suite**:
   - Exact commands the agent must execute to prove success (e.g., `just lint`, `just check-install`, unit tests).
6. **Mandatory Self-Cleanup Footer**:
   - Every generated prompt **MUST** terminate with this exact block:
   ```markdown
   ---
   ### Final Instruction
   > **IMPORTANT:** Once you have completed this task and verified all tests and requirements, delete this prompt file (`AGENT_PROMPT_<TASK_NAME>.txt`) so no temporary prompt files linger in the repository.
   ```

### 4. Write the File & Inform the User
- Write the formatted prompt content to the workspace root `AGENT_PROMPT_<TASK_NAME>.txt`.
- Inform the user:
  - The path of the generated prompt file.
  - A concise summary of the task objectives and requirements written into the prompt.
  - Recommended next steps (e.g., starting an agent session with `read AGENT_PROMPT_<TASK_NAME>.txt`).

---

## Handoff Prompt Template Reference

Use this template as the standard skeleton when drafting `AGENT_PROMPT_<TASK_NAME>.txt`:

```markdown
# Objective: <Single-sentence summary of the task>

<Paragraph expanding on the goal, why it is needed, and the expected end state.>

---

## Context & Background

- **Branch**: `<current branch>`
- **Recent Commits**:
  - `<hash> <commit subject>`
- **Architecture & Prior Art**:
  - <Key design decisions, patterns in the codebase, or related modules.>

---

## Requirements & Specifications

1. **<Requirement Area 1>**:
   - <Detailed functional requirement>
   - <Edge case handling>

2. **<Requirement Area 2>**:
   - <Detailed functional requirement>
   - <Idempotency / backup / error handling requirements>

---

## File Targets & Conventions

- **Target Files**:
  - [`path/to/file1.sh`](file:///absolute/path/to/file1.sh): <What to modify or create>
  - [`path/to/file2.md`](file:///absolute/path/to/file2.md): <Documentation updates>

- **Coding Conventions**:
  - Follow repository standards: POSIX/bash idioms, shellcheck clean, idempotency.
  - Preserve documentation integrity and existing comments.
  - Provide clickable file links using markdown format.

---

## Verification & Test Suite

Run the following commands to verify all changes:
```sh
just lint            # Must pass conventions and shellcheck cleanly
just check-install   # End-to-end sandbox verification
```

---

### Final Instruction
> **IMPORTANT:** Once you have completed this task and verified all tests and requirements, delete this prompt file (`AGENT_PROMPT_<TASK_NAME>.txt`) so no temporary prompt files linger in the repository.
```
