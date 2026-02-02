#compdef ralph
#
# Zsh completion for ralph
#
# Install: cp ralph.zsh ~/.local/share/zsh/site-functions/_ralph
#

_ralph() {
    local -a commands
    commands=(
        'init:Generate prd.json from a goal description'
        'extend:Add new tasks to a completed project'
        'run:Execute the Ralph loop on a project'
        'status:Show current project progress'
        'stack:Show PRD expansion stack status'
        'watch:Real-time task visualization dashboard'
        'flow:Dependency tree visualization'
    )

    local -a global_opts
    global_opts=(
        '(-h --help)'{-h,--help}'[Show help message]'
        '(-v --version)'{-v,--version}'[Show version]'
    )

    _arguments -C \
        $global_opts \
        '1:command:->command' \
        '*::arg:->args'

    case "$state" in
        command)
            _describe -t commands 'ralph commands' commands
            _files -/
            ;;
        args)
            case "$words[1]" in
                init)
                    _arguments \
                        '(-f --file)'{-f,--file}'[Read goal from file]:file:_files' \
                        '(-d --dir)'{-d,--dir}'[Output directory]:directory:_files -/' \
                        '(-p --prd)'{-p,--prd}'[Output PRD filename]:file:_files -g "*.json"' \
                        '--complexity[Target number of tasks]:number:(10 15 20 25 30 50)' \
                        '--dry-run[Preview without writing]' \
                        '(-h --help)'{-h,--help}'[Show help]' \
                        '*:goal:'
                    ;;
                extend)
                    _arguments \
                        '(-f --file)'{-f,--file}'[Read goal from file]:file:_files' \
                        '(-d --dir)'{-d,--dir}'[Project directory]:directory:_files -/' \
                        '(-p --prd)'{-p,--prd}'[PRD filename]:file:_files -g "*.json"' \
                        '--dry-run[Preview without writing]' \
                        '(-h --help)'{-h,--help}'[Show help]' \
                        '*:goal:'
                    ;;
                run)
                    _arguments \
                        '(-n --max-iterations)'{-n,--max-iterations}'[Maximum iterations]:number:(10 25 50 100 200)' \
                        '(-t --timeout)'{-t,--timeout}'[Timeout per iteration]:seconds:(300 600 900 1200 1800 3600)' \
                        '(-p --prd)'{-p,--prd}'[PRD filename]:file:_files -g "*.json"' \
                        '(-o --output)'{-o,--output}'[Output directory]:directory:_files -/' \
                        '(-q --quiet)'{-q,--quiet}'[Minimal output]' \
                        '--no-verify[Skip verification step]' \
                        '--no-expand[Disable automatic task expansion]' \
                        '--no-optimizer[Disable pre-iteration task optimizer]' \
                        '--expansion-threshold[Complexity threshold for expansion]:number:(3 4 5)' \
                        '--max-stack-depth[Maximum sub-PRD nesting]:number:(1 2 3 4 5)' \
                        '--sudo-pass[Enable sudo password piping]:envvar:(RALPH_SUDO_PASS SUDO_PASSWORD)' \
                        '--dry-run[Preview only]' \
                        '(-h --help)'{-h,--help}'[Show help]' \
                        '*:project directory:_files -/'
                    ;;
                status)
                    _arguments \
                        '(-p --prd)'{-p,--prd}'[PRD filename]:file:_files -g "*.json"' \
                        '(-h --help)'{-h,--help}'[Show help]' \
                        '*:project directory:_files -/'
                    ;;
                stack)
                    _arguments \
                        '(-p --prd)'{-p,--prd}'[PRD filename]:file:_files -g "*.json"' \
                        '(-h --help)'{-h,--help}'[Show help]' \
                        '*:project directory:_files -/'
                    ;;
                watch)
                    _arguments \
                        '(-p --prd)'{-p,--prd}'[PRD filename]:file:_files -g "*.json"' \
                        '(-r --refresh)'{-r,--refresh}'[Refresh interval]:seconds:(1 2 3 5 10)' \
                        '(-h --help)'{-h,--help}'[Show help]' \
                        '*:project directory:_files -/'
                    ;;
                flow)
                    _arguments \
                        '(-p --prd)'{-p,--prd}'[PRD filename]:file:_files -g "*.json"' \
                        '(-r --refresh)'{-r,--refresh}'[Refresh interval]:seconds:(1 2 3 5 10)' \
                        '(-h --help)'{-h,--help}'[Show help]' \
                        '*:project directory:_files -/'
                    ;;
            esac
            ;;
    esac
}

_ralph "$@"
