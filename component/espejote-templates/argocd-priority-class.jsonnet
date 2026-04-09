local esp = import 'espejote.libsonnet';
local admission = esp.ALPHA.admission;

local pod = admission.admissionRequest().object;
local hasPriorityClass = std.get(pod.spec, 'priorityClassName') != null;

local removePriority =
  admission.jsonPatchOp(
    'remove',
    '/spec/priority',
  );

local addPriorityClass = if hasPriorityClass then
  admission.jsonPatchOp(
    'replace',
    '/spec/priorityClassName',
    'system-cluster-critical',
  )
else
  admission.jsonPatchOp(
    'add',
    '/spec/priorityClassName',
    'system-cluster-critical',
  );

admission.patched('added priorityClassName', admission.assertPatch([ removePriority, addPriorityClass ]))
