# Bash completion for ralph
#
# Install: cp ralph.bash ~/.local/share/bash-completion/completions/ralph
#

_ralph_completions() {
    local cur prev opts commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Commands
    commands="init run status"

    # Determine if we're completing a command or option
    local cmd=""
    for ((i=1; i < COMP_CWORD; i++)); do
        case "${COMP_WORDS[i]}" in
            init|run|status)
                cmd="${COMP_WORDS[i]}"
                break
                ;;
        esac
    done

    # Command-specific completions
    case "$cmd" in
        init)
            case "${prev}" in
                -f|--file)
                    COMPREPLY=($(compgen -f -- "${cur}"))
                    return 0
                    ;;
                -d|--dir)
                    COMPREPLY=($(compgen -d -- "${cur}"))
                    return 0
                    ;;
                -p|--prd)
                    COMPREPLY=($(compgen -f -X '!*.json' -- "${cur}"))
                    return 0
                    ;;
                --complexity)
                    COMPREPLY=($(compgen -W "10 15 20 25 30 50" -- "${cur}"))
                    return 0
                    ;;
            esac
            if [[ "${cur}" == -* ]]; then
                COMPREPLY=($(compgen -W "-f --file -d --dir -p --prd --complexity --dry-run -h --help" -- "${cur}"))
            fi
            return 0
            ;;
        run)
            case "${prev}" in
                -n|--max-iterations)
                    COMPREPLY=($(compgen -W "10 25 50 100 200" -- "${cur}"))
                    return 0
                    ;;
                -t|--timeout)
                    COMPREPLY=($(compgen -W "300 600 900 1200 1800 3600" -- "${cur}"))
                    return 0
                    ;;
                -p|--prd)
                    COMPREPLY=($(compgen -f -X '!*.json' -- "${cur}"))
                    return 0
                    ;;
                -o|--output)
                    COMPREPLY=($(compgen -d -- "${cur}"))
                    return 0
                    ;;
            esac
            if [[ "${cur}" == -* ]]; then
                COMPREPLY=($(compgen -W "-n --max-iterations -t --timeout -p --prd -o --output -q --quiet --no-verify --dry-run -h --help" -- "${cur}"))
            else
                COMPREPLY=($(compgen -d -- "${cur}"))
            fi
            return 0
            ;;
        status)
            case "${prev}" in
                -p|--prd)
                    COMPREPLY=($(compgen -f -X '!*.json' -- "${cur}"))
                    return 0
                    ;;
            esac
            if [[ "${cur}" == -* ]]; then
                COMPREPLY=($(compgen -W "-p --prd -h --help" -- "${cur}"))
            else
                COMPREPLY=($(compgen -d -- "${cur}"))
            fi
            return 0
            ;;
    esac

    # Top-level completions
    if [[ "${cur}" == -* ]]; then
        COMPREPLY=($(compgen -W "-h --help -v --version" -- "${cur}"))
    else
        # Complete commands or directories
        COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
        COMPREPLY+=($(compgen -d -- "${cur}"))
    fi

    return 0
}

complete -F _ralph_completions ralph
