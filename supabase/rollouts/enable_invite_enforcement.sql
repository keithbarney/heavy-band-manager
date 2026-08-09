-- Run this reviewed statement in the production Supabase SQL editor only
-- after the corresponding App Store build has reached the explicit adoption
-- or support cutoff recorded in Linear. Merely having a build available is not
-- sufficient: older installed clients lose direct-join access after this
-- switch. The migration defaults this flag to false so they can keep joining
-- during the app rollout.

update public.security_flags
set invite_enforcement_enabled = true
where singleton;
