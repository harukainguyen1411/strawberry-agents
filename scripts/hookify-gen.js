// hookify-gen.js - writes Node.js hook files to hookify plugin cache
// Run: node scripts/hookify-gen.js
'use strict';
var fs = require('fs');

var BASE = 'C:/Users/AD/.claude/plugins/cache/claude-code-plugins/hookify/0.1.0/hooks';

// ----------------------------------------------------------------
// hookify-core.js content
// ----------------------------------------------------------------
var CORE = [
"// hookify-core.js - shared logic ported from Python to Node.js",
"'use strict';",
"var fs2 = require('fs');",
"var path = require('path');",
"",
"function extractFrontmatter(content) {",
"  if (content.slice(0,3) !== '---') return { frontmatter: {}, message: content };",
"  var parts = content.split('---');",
"  if (parts.length < 3) return { frontmatter: {}, message: content };",
"  var fmText = parts[1];",
"  var message = parts.slice(2).join('---').trim();",
"  var fm = {};",
"  var lines = fmText.split('\\n');",
"  var currentKey = null, currentList = [], currentDict = {}, inList = false, inDictItem = false;",
"  for (var i = 0; i < lines.length; i++) {",
"    var line = lines[i];",
"    var stripped = line.trim();",
"    if (!stripped || stripped.charAt(0) === '#') continue;",
"    var indent = line.length - line.replace(/^\\s+/, '').length;",
"    if (indent === 0 && line.indexOf(':') !== -1 && stripped.charAt(0) !== '-') {",
"      if (inList && currentKey) {",
"        if (inDictItem && Object.keys(currentDict).length > 0) { currentList.push(currentDict); currentDict = {}; }",
"        fm[currentKey] = currentList; inList = false; inDictItem = false; currentList = [];",
"      }",
"      var ci = line.indexOf(':');",
"      var key = line.slice(0, ci).trim();",
"      var value = line.slice(ci + 1).trim();",
"      if (!value) { currentKey = key; inList = true; currentList = []; }",
"      else {",
"        value = value.replace(/^[\"']|[\"']$/g, '');",
"        if (value.toLowerCase() === 'true') value = true;",
"        else if (value.toLowerCase() === 'false') value = false;",
"        fm[key] = value;",
"      }",
"    } else if (stripped.charAt(0) === '-' && inList) {",
"      if (inDictItem && Object.keys(currentDict).length > 0) { currentList.push(currentDict); currentDict = {}; }",
"      var itemText = stripped.slice(1).trim();",
"      if (itemText.indexOf(':') !== -1 && itemText.indexOf(',') !== -1) {",
"        var itemDict = {};",
"        itemText.split(',').forEach(function(part) {",
"          if (part.indexOf(':') !== -1) {",
"            var c2 = part.indexOf(':');",
"            itemDict[part.slice(0,c2).trim()] = part.slice(c2+1).trim().replace(/^[\"']|[\"']$/g,'');",
"          }",
"        });",
"        currentList.push(itemDict); inDictItem = false;",
"      } else if (itemText.indexOf(':') !== -1) {",
"        inDictItem = true;",
"        var ci2 = itemText.indexOf(':');",
"        currentDict = {};",
"        currentDict[itemText.slice(0,ci2).trim()] = itemText.slice(ci2+1).trim().replace(/^[\"']|[\"']$/g,'');",
"      } else { currentList.push(itemText.replace(/^[\"']|[\"']$/g,'')); inDictItem = false; }",
"    } else if (indent > 2 && inDictItem && stripped.indexOf(':') !== -1) {",
"      var ci3 = stripped.indexOf(':');",
"      currentDict[stripped.slice(0,ci3).trim()] = stripped.slice(ci3+1).trim().replace(/^[\"']|[\"']$/g,'');",
"    }",
"  }",
"  if (inList && currentKey) { if (inDictItem && Object.keys(currentDict).length > 0) currentList.push(currentDict); fm[currentKey] = currentList; }",
"  return { frontmatter: fm, message: message };",
"}",
"",
"function ruleFromDict(fm, message) {",
"  var conditions = [];",
"  if (Array.isArray(fm.conditions)) {",
"    conditions = fm.conditions.map(function(c) { return { field: c.field||'', operator: c.operator||'regex_match', pattern: c.pattern||'' }; });",
"  }",
"  var simplePattern = fm.pattern;",
"  if (simplePattern && conditions.length === 0) {",
"    var ev = fm.event || 'all';",
"    var field = ev === 'bash' ? 'command' : ev === 'file' ? 'new_text' : 'content';",
"    conditions = [{ field: field, operator: 'regex_match', pattern: simplePattern }];",
"  }",
"  return { name: fm.name||'unnamed', enabled: fm.enabled!==false, event: fm.event||'all',",
"    pattern: simplePattern||null, conditions: conditions, action: fm.action||'warn',",
"    toolMatcher: fm.tool_matcher||null, message: (message||'').trim() };",
"}",
"",
"function loadRuleFile(fp) {",
"  var content;",
"  try { content = fs2.readFileSync(fp, 'utf8'); } catch(e) { process.stderr.write('Warning: '+e.message+'\\n'); return null; }",
"  var res = extractFrontmatter(content);",
"  var fm = res.frontmatter; var msg = res.message;",
"  if (!fm || Object.keys(fm).length === 0) return null;",
"  try { return ruleFromDict(fm, msg); } catch(e) { return null; }",
"}",
"",
"function loadRules(event) {",
"  var claudeDir = '.claude';",
"  var files;",
"  try {",
"    var entries = fs2.readdirSync(claudeDir);",
"    files = entries.filter(function(f) { return /^hookify\\..+\\.local\\.md$/.test(f); }).map(function(f) { return path.join(claudeDir, f); });",
"  } catch(e) { return []; }",
"  var rules = [];",
"  for (var i = 0; i < files.length; i++) {",
"    var rule = loadRuleFile(files[i]);",
"    if (!rule) continue;",
"    if (event && rule.event !== 'all' && rule.event !== event) continue;",
"    if (rule.enabled) rules.push(rule);",
"  }",
"  return rules;",
"}",
"",
"var regexCache = {};",
"function getRegex(p) { if (!regexCache[p]) regexCache[p] = new RegExp(p, 'i'); return regexCache[p]; }",
"",
"function extractField(field, toolName, toolInput, inputData) {",
"  if (field in toolInput) { var v = toolInput[field]; return typeof v === 'string' ? v : String(v); }",
"  if (inputData) {",
"    if (field === 'reason') return inputData.reason || '';",
"    if (field === 'transcript') {",
"      var tp = inputData.transcript_path;",
"      if (tp) { try { return fs2.readFileSync(tp,'utf8'); } catch(e) { return ''; } }",
"      return '';",
"    }",
"    if (field === 'user_prompt') return inputData.user_prompt || '';",
"  }",
"  if (toolName === 'Bash' && field === 'command') return toolInput.command || '';",
"  if (toolName === 'Write' || toolName === 'Edit') {",
"    if (field === 'content') return toolInput.content || toolInput.new_string || '';",
"    if (field === 'new_text' || field === 'new_string') return toolInput.new_string || '';",
"    if (field === 'old_text' || field === 'old_string') return toolInput.old_string || '';",
"    if (field === 'file_path') return toolInput.file_path || '';",
"  }",
"  if (toolName === 'MultiEdit') {",
"    if (field === 'file_path') return toolInput.file_path || '';",
"    if (field === 'new_text' || field === 'content') return (toolInput.edits||[]).map(function(e){return e.new_string||'';}).join(' ');",
"  }",
"  return null;",
"}",
"",
"function checkCondition(c, toolName, toolInput, inputData) {",
"  var v = extractField(c.field, toolName, toolInput, inputData);",
"  if (v === null) return false;",
"  try {",
"    if (c.operator === 'regex_match') return getRegex(c.pattern).test(v);",
"    if (c.operator === 'contains') return v.indexOf(c.pattern) !== -1;",
"    if (c.operator === 'equals') return v === c.pattern;",
"    if (c.operator === 'not_contains') return v.indexOf(c.pattern) === -1;",
"    if (c.operator === 'starts_with') return v.indexOf(c.pattern) === 0;",
"    if (c.operator === 'ends_with') return v.slice(-c.pattern.length) === c.pattern;",
"  } catch(e) {}",
"  return false;",
"}",
"",
"function ruleMatches(rule, inputData) {",
"  var toolName = inputData.tool_name || '';",
"  var toolInput = inputData.tool_input || {};",
"  if (rule.toolMatcher && rule.toolMatcher !== '*' && rule.toolMatcher.split('|').indexOf(toolName) === -1) return false;",
"  if (rule.conditions.length === 0) return false;",
"  return rule.conditions.every(function(c) { return checkCondition(c, toolName, toolInput, inputData); });",
"}",
"",
"function evaluateRules(rules, inputData) {",
"  var hookEvent = inputData.hook_event_name || '';",
"  var blocking = [], warning = [];",
"  rules.forEach(function(rule) {",
"    if (ruleMatches(rule, inputData)) (rule.action === 'block' ? blocking : warning).push(rule);",
"  });",
"  if (blocking.length > 0) {",
"    var combined = blocking.map(function(r){return '**['+r.name+']**\\n'+r.message;}).join('\\n\\n');",
"    if (hookEvent === 'Stop') return { decision: 'block', reason: combined, systemMessage: combined };",
"    if (hookEvent === 'PreToolUse' || hookEvent === 'PostToolUse') return { hookSpecificOutput: { hookEventName: hookEvent, permissionDecision: 'deny' }, systemMessage: combined };",
"    return { systemMessage: combined };",
"  }",
"  if (warning.length > 0) return { systemMessage: warning.map(function(r){return '**['+r.name+']**\\n'+r.message;}).join('\\n\\n') };",
"  return {};",
"}",
"",
"function runHook(event) {",
"  var raw = '';",
"  process.stdin.setEncoding('utf8');",
"  process.stdin.on('data', function(c) { raw += c; });",
"  process.stdin.on('end', function() {",
"    var inputData = {};",
"    try { if (raw.trim()) inputData = JSON.parse(raw); } catch(e) {}",
"    try {",
"      var rules = loadRules(event);",
"      var result = evaluateRules(rules, inputData);",
"      process.stdout.write(JSON.stringify(result) + '\\n');",
"    } catch(e) {",
"      process.stdout.write(JSON.stringify({ systemMessage: 'Hookify error: '+e.message }) + '\\n');",
"    }",
"    process.exit(0);",
"  });",
"}",
"",
"module.exports = { runHook: runHook, loadRules: loadRules, evaluateRules: evaluateRules };"
].join('\n');

fs.writeFileSync(BASE + '/hookify-core.js', CORE, 'utf8');
console.log('wrote hookify-core.js: ' + CORE.length + ' bytes');

// ----------------------------------------------------------------
// Entry point scripts
// ----------------------------------------------------------------
function writeEntry(name, eventArg) {
  var content = [
    "#!/usr/bin/env node",
    "// " + name + ".js - hookify hook (Node.js port of " + name + ".py)",
    "'use strict';",
    "var pluginRoot = process.env.CLAUDE_PLUGIN_ROOT || require('path').join(__dirname, '..');",
    "var core = require(require('path').join(pluginRoot, 'hooks', 'hookify-core.js'));",
    "core.runHook(" + eventArg + ");",
    ""
  ].join('\n');
  fs.writeFileSync(BASE + '/' + name + '.js', content, 'utf8');
  console.log('wrote ' + name + '.js');
}

writeEntry('stop', "'stop'");
writeEntry('pretooluse', "null");
writeEntry('posttooluse', "null");
writeEntry('userpromptsubmit', "'prompt'");

// ----------------------------------------------------------------
// Update hooks.json: replace python3 with node
// ----------------------------------------------------------------
var hooksJsonPath = BASE + '/hooks.json';
var hooksJson = JSON.parse(fs.readFileSync(hooksJsonPath, 'utf8'));

function fixCommand(cmd) {
  return cmd
    .replace('python3 ${CLAUDE_PLUGIN_ROOT}/hooks/stop.py', 'node "${CLAUDE_PLUGIN_ROOT}/hooks/stop.js"')
    .replace('python3 ${CLAUDE_PLUGIN_ROOT}/hooks/pretooluse.py', 'node "${CLAUDE_PLUGIN_ROOT}/hooks/pretooluse.js"')
    .replace('python3 ${CLAUDE_PLUGIN_ROOT}/hooks/posttooluse.py', 'node "${CLAUDE_PLUGIN_ROOT}/hooks/posttooluse.js"')
    .replace('python3 ${CLAUDE_PLUGIN_ROOT}/hooks/userpromptsubmit.py', 'node "${CLAUDE_PLUGIN_ROOT}/hooks/userpromptsubmit.js"');
}

function walkHooks(obj) {
  if (Array.isArray(obj)) { obj.forEach(walkHooks); return; }
  if (obj && typeof obj === 'object') {
    if (typeof obj.command === 'string') obj.command = fixCommand(obj.command);
    Object.values(obj).forEach(walkHooks);
  }
}

walkHooks(hooksJson);
fs.writeFileSync(hooksJsonPath, JSON.stringify(hooksJson, null, 2) + '\n', 'utf8');
console.log('updated hooks.json');
console.log('done.');
