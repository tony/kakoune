# Kakoune Exuberant CTags support script
#
# This script requires the readtags command available in ctags source but
# not installed by default

decl str-list ctagsfiles 'tags'

def -params 0..1 \
    -shell-candidates '
        ( for tags in $(printf %s\\n "${kak_opt_ctagsfiles}" | tr \':\' \'\n\'); do
              namecache=$(dirname ${tags})/.kak.$(basename ${tags}).namecache
              if [ -z "$(find ${namecache} -prune -newer ${tags})" ]; then
                  cat ${tags} | cut -f 1 | uniq > ${namecache}
              fi
              cat ${namecache}
          done )' \
    -docstring 'Jump to tag definition' \
    tag \
    %{ %sh{
        export tagname=${1:-${kak_selection}}
        for tags in $(printf %s\\n "${kak_opt_ctagsfiles}" | tr ':' '\n'); do
            export tagroot="$(readlink -f $(dirname "$tags"))/"
            readtags -t "${tags}" ${tagname} | awk -F '\t|\n' '
            /[^\t]+\t[^\t]+\t\/\^.*\$?\// {
                re=$0;
                sub(".*\t/\\^", "", re); sub("\\$?/$", "", re); gsub("(\\{|\\}|\\\\E).*$", "", re);
                keys=re; gsub(/</, "<lt>", keys); gsub(/\t/, "<c-v><c-i>", keys);
                out = out " %{" $2 " {MenuInfo}" re "} %{eval -collapse-jumps %{ try %{ edit %{" $2 "}; exec %{/\\Q" keys "<ret>vc} } catch %{ echo %{unable to find tag} } } }"
            }
            /[^\t]+\t[^\t]+\t[0-9]+/ { out = out " %{" $2 ":" $3 "} %{eval -collapse-jumps %{ edit %{" ENVIRON["tagroot"] $2 "} %{" $3 "}}}" }
            END { print length(out) == 0 ? "echo -color Error no such tag " ENVIRON["tagname"] : "menu -markup -auto-single " out }'
        done
    }}

def tag-complete -docstring "Insert completion candidates for the current selection into the buffer's local variables" %{ eval -draft %{
    exec <space>hb<a-k>^\w+$<ret>
    %sh{ (
        compl=$(readtags -p "$kak_selection" | cut -f 1 | sort | uniq | sed -e 's/:/\\:/g' | sed -e 's/\n/:/g' )
        compl="${kak_cursor_line}.${kak_cursor_column}+${#kak_selection}@${kak_timestamp}:${compl}"
        printf %s\\n "set buffer=$kak_bufname ctags_completions '${compl}'" | kak -p ${kak_session}
    ) > /dev/null 2>&1 < /dev/null & }
}}

def ctags-funcinfo -docstring "Display ctags information about a selected function" %{
    eval -draft %{
        try %{
            exec -no-hooks '[(;B<a-k>[a-zA-Z_]+\(<ret><a-;>'
            %sh{
                sigs=$(readtags -e ${kak_selection%(} | grep kind:f | sed -re 's/^(\S+).*((class|struct|namespace):(\S+))?.*signature:(.*)$/\5 [\4::\1]/')
                if [ -n "$sigs" ]; then
                    printf %s\\n "eval -client ${kak_client} %{info -anchor $kak_cursor_line.$kak_cursor_column -placement above '$sigs'}"
                fi
            }
        }
    }
}

def ctags-enable-autoinfo -docstring "Automatically display ctags information about function" %{
     hook window -group ctags-autoinfo NormalIdle .* ctags-funcinfo
     hook window -group ctags-autoinfo InsertIdle .* ctags-funcinfo
}

def ctags-disable-autoinfo -docstring "Disable automatic ctags information displaying" %{ rmhooks window ctags-autoinfo }

decl str ctagsopts "-R"
decl str ctagspaths "."

def ctags-generate -docstring 'Generate tag file asynchronously' %{
    echo -color Information "launching tag generation in the background"
    %sh{ (
        while ! mkdir .tags.kaklock 2>/dev/null; do sleep 1; done
        trap 'rmdir .tags.kaklock' EXIT

        if ctags -f .tags.kaktmp ${kak_opt_ctagsopts} ${kak_opt_ctagspaths}; then
            mv .tags.kaktmp tags
            msg="tags generation complete"
        else
            msg="tags generation failed"
        fi

        printf %s\\n "eval -client $kak_client echo -color Information '${msg}'" | kak -p ${kak_session}
    ) > /dev/null 2>&1 < /dev/null & }
}

def update-tags -docstring 'Update tags for the given file' %{
        %sh{ (
            while ! mkdir .tags.kaklock 2>/dev/null; do sleep 1; done
	        trap 'rmdir .tags.kaklock' EXIT

            if ctags -f .file_tags.kaktmp ${kak_opt_ctagsopts} $kak_bufname; then
                grep -Fv "$(printf '\t%s\t' "$kak_bufname")" tags | grep -v '^!' | sort --merge - .file_tags.kaktmp > .tags.kaktmp
                mv .tags.kaktmp tags
                msg="tags updated for $kak_bufname"
            else
                msg="tags update failed for $kak_bufname"
            fi
        ) > /dev/null 2>&1 < /dev/null & }
}
