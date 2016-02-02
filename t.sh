# for bash-git-prompt integration, shows current bucket if you're in one
function prompt_callback {
    if [ -x "$(which t)" -a -n "$T_BUCKET_ID" ] ; then
        echo -n " bucket:$(t title "$T_BUCKET_ID")"
    fi
}
