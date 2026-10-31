#!/usr/bin/env node
// Compares the PR's proposed task statuses to the actual target branch.
import fs from "node:fs";
import {execFileSync} from "node:child_process";
import {auditProposedTaskChanges} from "./pr-gate-core.mjs";
const get=p=>JSON.parse(fs.readFileSync(p,"utf8"));
const branch=process.env.GITHUB_HEAD_REF||process.env.PR_HEAD_REF||"";
const base=process.env.GITHUB_BASE_REF||"main";
function baseStatus(){
 try{return JSON.parse(execFileSync("git",["show","refs/remotes/origin/"+base+":tasks/status.json"],{encoding:"utf8"}));}
 catch(e){
   // Bootstrap ONLY if the git object is absent, not if git itself is broken.
   try{execFileSync("git",["cat-file","-e","refs/remotes/origin/"+base+":tasks/status.json"]);throw e;}
   catch(err){if(err===e)throw err;return null;}
 }
}
try{
 if(!branch)throw Error("PR head branch not provided; never silently assume bootstrap");
 const result=auditProposedTaskChanges(baseStatus(),get("tasks/status.json"),get("tasks/manifest.json"),branch);
 console.log("PASS: base-branch task transition audit",JSON.stringify(result));
}catch(e){console.error("FAIL: "+e.message);process.exitCode=1;}
