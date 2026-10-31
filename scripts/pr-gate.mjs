#!/usr/bin/env node
// Compare PR task transitions with target branch records; never trust PR-updated prerequisites.
import fs from "node:fs";
import {execFileSync} from "node:child_process";
import {auditProposedTaskChanges} from "./pr-gate-core.mjs";
const get=p=>JSON.parse(fs.readFileSync(p,"utf8"));
const branch=process.env.GITHUB_HEAD_REF||process.env.PR_HEAD_REF||"";
const base=process.env.GITHUB_BASE_REF||"main";
function readBaseJson(file){
 const ref="refs/remotes/origin/"+base;
 // If base ref doesn't exist, abort: only a missing *file* permits bootstrap.
 execFileSync("git",["rev-parse","--verify",ref],{stdio:"pipe"});
 try {return JSON.parse(execFileSync("git",["show",ref+":"+file],{encoding:"utf8",stdio:["ignore","pipe","pipe"]}));}
 catch(err){
   // If ref contains file but JSON is invalid, do not silently treat as new bootstrap.
   try{execFileSync("git",["cat-file","-e",ref+":"+file],{stdio:"pipe"});}
   catch {return null;}
   throw err;
 }
}
try{
 if(!branch)throw Error("PR head branch not provided");
 const mainStatus=readBaseJson("tasks/status.json");
 const mainManifest=readBaseJson("tasks/manifest.json");
 if(!!mainStatus!==!!mainManifest)throw Error("Target branch has incomplete governance files");
 const result=auditProposedTaskChanges(mainStatus,get("tasks/status.json"),get("tasks/manifest.json"),branch,mainManifest);
 console.log("PASS: target-branch task audit",JSON.stringify(result));
}catch(e){console.error("FAIL: "+e.message);process.exitCode=1;}
