// Pure policy checks for task changes proposed in a pull request.
// Base branch status is authoritative: a PR cannot satisfy its own prerequisites.
const allowedStates = new Set(["TODO","IN_PROGRESS","DONE"]);
function demand(ok, message){if(!ok)throw Error(message);}
export function auditProposedTaskChanges(base, next, manifest, branch){
 demand(next?.schemaVersion===1 && next?.tasks && manifest?.tasks,"Task manifest/status missing or invalid");
 const ids=Object.keys(manifest.tasks);
 demand(ids.length && ids.every(id=>next.tasks[id]),"Proposed task status missing task entries");
 demand(Object.keys(next.tasks).length===ids.length,"Proposed task status contains unknown IDs");
 if(!base){
   demand(branch==="setup/mg-000-foundation","Bootstrap exception applies only to initial foundation branch");
   demand(next.tasks["MG-000"]?.state==="IN_PROGRESS","Bootstrap MG-000 must be IN_PROGRESS");
   demand(ids.every(id=>next.tasks[id].state!=="DONE"),"Bootstrap cannot mark tasks DONE");
   demand(ids.filter(id=>next.tasks[id].state==="IN_PROGRESS").length===1,"Bootstrap may start only MG-000");
   return {bootstrap:true,changes:["MG-000"],detail:"bootstrap pending review"};
 }
 demand(base.schemaVersion===1 && base.tasks,"Target branch task status invalid");
 demand(ids.every(id=>base.tasks[id]),"Proposed manifest changes need separate approved governance review");
 const changed=ids.filter(id=>JSON.stringify(base.tasks[id])!==JSON.stringify(next.tasks[id]));
 demand(changed.length<=1,"One PR may change status of only one task");
 const taskId=changed[0]||null;
 if(!taskId)return {bootstrap:false,changes:[],detail:"no task state transitions"};
 demand(new RegExp("^task/"+taskId+"(?:-|$)").test(branch),"Task status changes require task/ID-name branch; found "+branch);
 const b=base.tasks[taskId],n=next.tasks[taskId],task=manifest.tasks[taskId];
 demand(n.owner===task.owner && b.owner===task.owner,"Task owner mismatch");
 demand(allowedStates.has(b.state) && allowedStates.has(n.state),"Invalid state");
 const allowed=(b.state==="TODO" && n.state==="IN_PROGRESS") || (b.state==="IN_PROGRESS" && n.state==="DONE");
 demand(allowed,taskId+" invalid state transition "+b.state+" -> "+n.state);
 const waiting=task.dependsOn.filter(id=>base.tasks[id]?.state!=="DONE");
 demand(!waiting.length,taskId+" prerequisites not DONE on target branch: "+waiting.join(", "));
 if(n.state==="IN_PROGRESS"){
   demand(n.startedBy===task.owner && n.startedOn,"Start evidence missing owner/date");
   demand(n.evidence===null,"IN_PROGRESS must not claim completed evidence");
 }else{
   demand(n.startedBy===task.owner && n.completedBy===task.owner && n.completedOn,"Completion metadata absent");
   demand(n.evidence===task.evidence,"Evidence path does not match task manifest");
 }
 return {bootstrap:false,changes:[taskId],detail:b.state+" -> "+n.state};
}
