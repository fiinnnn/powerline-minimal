setopt PROMPT_SUBST

separator_char=''
separator_char_pts='\ue0b1'
separator_char_tty='>'

case "$(tty)" in
    "/dev/pts"*) separator_char=$separator_char_pts ;;
    "/dev/tty"*) separator_char=$separator_char_tty ;;
esac

git_branch_sym='\ue0a0'
git_detached_head_sym='\u233f'
git_untracked_sym="?:"
git_unstaged_sym="U:"
git_staged_sym="S:"
git_ahead_sym='\u2191'
git_behind_sym='\u2193'
rbenv_sym='r'

git_clean_color='blue'
git_untracked_color='red'
git_unstaged_color='yellow'
git_staged_color='cyan'
rbenv_color='red'
reset_color='%{%f%k%}'

print-last-code() {
    [[ (-n "$last_code") && ($last_code -ne 0) ]] && echo -n " %F{red}$last_code$reset_color $separator_char"
}

print-git-status() {
    if [[ -n "$(git rev-parse --is-inside-work-tree 2> /dev/null)" ]]; then
        local branch=$(git symbolic-ref --short HEAD 2> /dev/null)

        if [[ -n "$branch" ]]; then
            # Branch

            text_color=$git_clean_color
            local git_status

            read -r commits_behind commits_ahead <<< "$(git-upstream-status)"
            [[ "$commits_ahead" -gt 0 ]] && git_status+=" $git_ahead_sym$commits_ahead"
            [[ "$commits_behind" -gt 0 ]] && git_status+=" $git_behind_sym$commits_behind"

            local stash_count
            stash_count="$(git stash list 2> /dev/null | wc -l | tr -d ' ')"
            [[ "$stash_count" -gt 0 ]] && git_status+=" {$stash_count}"

            read -r untracked_count unstaged_count staged_count <<< "$(git-status)"
            if [[ "$untracked_count" -gt 0 || "$unstaged_count" -gt 0 || "$staged_count" -gt 0 ]]; then
                [[ "$staged_count" -gt 0 ]] && git_status+=" $git_staged_sym$staged_count" && text_color=$git_staged_color
                [[ "$unstaged_count" -gt 0 ]] && git_status+=" $git_unstaged_sym$unstaged_count" && text_color=$git_unstaged_color
                [[ "$untracked_count" -gt 0 ]] && git_status+=" $git_untracked_sym$untracked_count" && text_color=$git_untracked_color
            fi

            echo -n "%F{$text_color} $git_branch_sym $branch$git_status"
        else
            # Detached head

            local ref=$(git rev-parse --short HEAD)

            echo -n "%F{blue} $git_detached_head_sym $ref"
        fi

        echo -n " $reset_color$separator_char"
    fi
}

print-rbenv-version() {
    if which rbenv &> /dev/null; then
        rbenv=$(rbenv version-name) || return
        if [ $rbenv != "system" ]; then
            echo -n " %F{$rbenv_color}$rbenv_sym $rbenv $reset_color$separator_char"
        fi
    fi
}

print-dir() {
    echo -n " $(sed "s:\([^/]\)[^/]*/:\1/:g" <<< ${PWD/#$HOME/\~}) $separator_char"
}

prompt() {
    print-last-code
    print-git-status
    print-rbenv-version
    print-dir
    echo -n " "
}

precmd() {
    last_code=$?
}

[[ ${precmd_functions[(r)precmd]} != "precmd" ]] && precmd_functions+=(precmd)

PROMPT='$(prompt)'

git-status() {
    git status --porcelain -u 2> /dev/null | awk '
    BEGIN {
        untracked=0;
        unstaged=0;
        staged=0;
    }
    {
        if ($0 ~ /^\?\? .+/) {
            untracked += 1
        } else {
            if ($0 ~ /^.[^ ] .+/) {
                unstaged += 1
            }
            if ($0 ~ /^[^ ]. .+/) {
                staged += 1
            }
        }
    }
    END {
        print untracked "\t" unstaged "\t" staged
    }'
}

git-upstream() {
    local ref
    ref="$(git symbolic-ref -q HEAD 2> /dev/null)" || return 1
    git for-each-ref --format="%(upstream:short)" "$ref"
}

git-upstream-status() {
    git rev-list --left-right --count "$(git-upstream)...HEAD" 2> /dev/null
}
