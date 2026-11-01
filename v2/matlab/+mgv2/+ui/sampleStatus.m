function st = sampleStatus(id, view)
%SAMPLESTATUS Display state of one sensor channel, derived only from the sample's own t_s/tick/valid fields.
%   st = mgv2.ui.sampleStatus(id, view)   st.state: "NONE" | "VALID" | "INVALID" | "STALE"; st.text; st.sample
%   STALE: the last sample is older than the channel period on the engine clock. It is never re-stamped.
s = view.samples.(char(id));
st = struct('state', "NONE", 'text', "NO SAMPLE", 'sample', s);
if isempty(s), return; end
if double(view.pose.tick_id) - double(s.tick_id) > view.period.(char(id))
    st.state = "STALE"; tag = "STALE";
elseif s.valid
    st.state = "VALID"; tag = "VALID";
else
    st.state = "INVALID"; tag = "INVALID " + s.invalid_reason;
end
st.text = sprintf("t=%.2f s | tick %d | %s", s.t_s, s.tick_id, tag);
end
