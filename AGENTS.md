# Project Instructions

- Use English for project documentation, code comments, commit messages, and assistant responses in this repository.
- Avoid promotional, portfolio, or interview-oriented wording.
- Treat documentation as public GitHub-facing documentation.
- Keep command-line helpers simple, explicit, and safe by default. Destructive actions must require an explicit option and, when practical, an interactive confirmation.
- Every executable script must include a short header comment near the top that explains what the script does, how to run it, and at least one concrete example command.
- Put interpreter or output-control directives before the header when required for correct behavior. Examples: a shell shebang must remain the first line of a shell script, and `@echo off` should be the first executable line of a `.cmd` file so header comments are not echoed to the terminal.
- If a wrapper script and its implementation can both be executed directly, each file must contain its own description, usage, examples, dependencies, and important limitations.
- Before executing an external executable or another helper script, print the command that is about to run. Shell built-ins, language-native functions, and PowerShell cmdlets do not need to be echoed individually.
- Prefer built-in operating-system or language facilities when they provide the required behavior. Document any required external dependency explicitly in the script header and in `README.md`.
- Public helpers must document supported parameters, default behavior, examples, dependencies, destructive behavior, and known limitations in `README.md`.
- Keep Windows and Linux variants behaviorally consistent when both are provided, while using platform-native implementation techniques where appropriate.
- Preserve meaningful exit codes: return `0` on success, a non-zero value on errors, and propagate the exit code of delegated implementations when a wrapper script is used.
