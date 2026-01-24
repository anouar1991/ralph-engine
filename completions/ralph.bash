# Bash completion for ralph
#
# Install: cp ralph.bash ~/.local/share/bash-completion/completions/ralph
#

_ralph_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Main options
    opts="-n --max-iterations -t --timeout -p --prd -o --output -q --quiet --no-verify --dry-run -h --help -v --version"

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
        *)
            ;;
    esac

    if [[ "${cur}" == -* ]]; then
        COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
    else
        # Complete directories for PROJECT_DIR argument
        COMPREPLY=($(compgen -d -- "${cur}"))
    fi

    return 0
}

complete -F _ralph_completions ralph
