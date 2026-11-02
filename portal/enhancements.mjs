/** Public, non-authoritative enhancement roadmap, separate from V2 task manifest. */
const states = new Set(["ACTIVE_UNMERGED","DRAFT_UNVERIFIED","PLANNED","BLOCKED","LOCAL_UNPUBLISHED","TESTED_BLOCKED","MERGED_IN_BRANCH"]);
const repoBase = "https://github.com/MdShabazS/MineGuard-MATLAB/";
export function validateEnhancements(data) {
  if (!data || data.schemaVersion !== 1 || data.phase !== "V2-ENHANCEMENTS" || !Array.isArray(data.items))
    throw Error("Enhancement roadmap schema unavailable");
  const seen = new Set();
  const groups = new Set(["engineering","campus"]);
  return data.items.map(item => {
    if (!item || !/^ENH-\d{3}$/.test(item.id) || seen.has(item.id))
      throw Error("Duplicate or invalid enhancement ID");
    seen.add(item.id);
    if (!groups.has(item.category) || !states.has(item.status) || !["P1","P2","P3"].includes(item.priority))
      throw Error("Invalid enhancement status/priority: " + item.id);
    for (const field of ["title","owner","detail","dependency","urlLabel"])
      if (typeof item[field] !== "string" || !item[field].trim()) throw Error("Missing enhancement field " + field);
    if (typeof item.url !== "string" || !item.url.startsWith(repoBase))
      throw Error("Invalid public enhancement URL: " + item.id);
    return item;
  });
}
export function enhancementLabel(status) {
  return {
    ACTIVE_UNMERGED:"In development · unmerged",
    DRAFT_UNVERIFIED:"Draft · not MATLAB-verified",
    PLANNED:"Planned",
    BLOCKED:"Waiting on prerequisites",
    LOCAL_UNPUBLISHED:"Local fix · not published",
    TESTED_BLOCKED:"Tested · acceptance blocked",
    MERGED_IN_BRANCH:"Merged in feature branch · not released"
  }[status] || "Unverified";
}
