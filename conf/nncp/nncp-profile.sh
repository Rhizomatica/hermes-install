# HF timeouts for NNCP commands run by hand, installed as
# /etc/profile.d/nncp.sh. The 10 s default kills HF sessions in the handshake.
NNCPDEADLINE=$(sed -n 's/^NNCPDEADLINE=//p' /etc/default/nncp-daemon 2>/dev/null | tail -n 1)
if [ -n "${NNCPDEADLINE}" ]; then
    export NNCPDEADLINE
else
    unset NNCPDEADLINE
fi
