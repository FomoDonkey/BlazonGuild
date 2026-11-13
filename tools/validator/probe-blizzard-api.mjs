#!/usr/bin/env node
/**
 * BlazonGuild - Blizzard Battle.net WoW Forever API Probe & Integration Test Runner
 * 
 * Verifies live responses, HTTP status codes, response schemas, and latency
 * for World of Warcraft: Forever endpoints without third-party dependencies.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '../../');

// 1. Simple .env parser (native zero-dependency)
function loadEnv() {
  const envPath = path.join(rootDir, '.env');
  const envVars = { ...process.env };
  if (fs.existsSync(envPath)) {
    const lines = fs.readFileSync(envPath, 'utf8').split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx !== -1) {
        const key = trimmed.slice(0, eqIdx).trim();
        const val = trimmed.slice(eqIdx + 1).trim();
        envVars[key] = val;
      }
    }
  }
  return envVars;
}

const env = loadEnv();
const CLIENT_ID = env.BLIZZARD_CLIENT_ID || '';
const CLIENT_SECRET = env.BLIZZARD_CLIENT_SECRET || '';
const REGION = env.BLIZZARD_REGION || 'eu';
const LOCALE = env.BLIZZARD_LOCALE || 'es_ES';
const RULESET_ID = env.WOW_FOREVER_RULESET_ID || '93';
const GUILD_SLUG = env.WOW_FOREVER_GUILD_SLUG || 'forever';
const TEST_CHAR = env.WOW_FOREVER_TEST_CHARACTER || 'el-peregrino';

const BASE_API_URL = `https://${REGION}.api.blizzard.com`;
const OAUTH_URL = 'https://oauth.battle.net/token';

console.log('='.repeat(78));
console.log('  BlazonGuild: WORLD OF WARCRAFT: FOREVER API INTEGRATION VALIDATOR');
console.log('='.repeat(78));
console.log(`Region: ${REGION.toUpperCase()} | Locale: ${LOCALE} | Ruleset: ${RULESET_ID}`);
console.log(`Test Guild: "${GUILD_SLUG}" | Test Character: "${TEST_CHAR}"`);
console.log('-'.repeat(78));

const testResults = [];

async function probeOAuth() {
  const result = {
    testName: 'OAuth Client Credentials',
    endpoint: OAUTH_URL,
    statusCategory: 'OFFICIALLY_DOCUMENTED',
    httpStatus: null,
    latencyMs: 0,
    success: false,
    fieldsAvailable: [],
    details: ''
  };

  if (!CLIENT_ID || !CLIENT_SECRET || CLIENT_ID.includes('your_')) {
    result.httpStatus = 'SKIPPED';
    result.details = 'Missing or default BLIZZARD_CLIENT_ID / BLIZZARD_CLIENT_SECRET in .env';
    testResults.push(result);
    return null;
  }

  const start = Date.now();
  try {
    const basicAuth = Buffer.from(`${CLIENT_ID}:${CLIENT_SECRET}`).toString('base64');
    const res = await fetch(OAUTH_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${basicAuth}`,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: 'grant_type=client_credentials'
    });
    result.latencyMs = Date.now() - start;
    result.httpStatus = res.status;

    if (res.ok) {
      const data = await res.json();
      result.success = true;
      result.fieldsAvailable = Object.keys(data);
      result.details = `Token acquired successfully. Expires in: ${data.expires_in}s`;
      testResults.push(result);
      return data.access_token;
    } else {
      const errText = await res.text();
      result.details = `Auth failed: ${errText.slice(0, 120)}`;
      testResults.push(result);
      return null;
    }
  } catch (err) {
    result.latencyMs = Date.now() - start;
    result.httpStatus = 'ERROR';
    result.details = err.message;
    testResults.push(result);
    return null;
  }
}

async function probeEndpoint(testName, pathStr, namespace, statusCategory, token) {
  const result = {
    testName,
    endpoint: `${pathStr}?namespace=${namespace}&locale=${LOCALE}`,
    statusCategory,
    httpStatus: null,
    latencyMs: 0,
    success: false,
    fieldsAvailable: [],
    details: ''
  };

  if (!token) {
    result.httpStatus = 'SKIPPED';
    result.details = 'Requires valid OAuth token (Credentials not provided)';
    testResults.push(result);
    return;
  }

  const fullUrl = `${BASE_API_URL}${pathStr}?namespace=${namespace}&locale=${LOCALE}`;
  const start = Date.now();

  try {
    const res = await fetch(fullUrl, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    result.latencyMs = Date.now() - start;
    result.httpStatus = res.status;

    if (res.ok) {
      const json = await res.json();
      result.success = true;
      result.fieldsAvailable = Object.keys(json);
      result.samplePayload = json;
      result.details = `Valid JSON returned (${result.fieldsAvailable.join(', ')})`;
    } else if (res.status === 404) {
      const errText = await res.text();
      result.details = `404 Not Found: ${errText.slice(0, 120)}`;
    } else {
      const errText = await res.text();
      result.details = `HTTP ${res.status}: ${errText.slice(0, 120)}`;
    }
  } catch (err) {
    result.latencyMs = Date.now() - start;
    result.httpStatus = 'ERROR';
    result.details = err.message;
  }

  testResults.push(result);
}

async function runValidationSuite() {
  const token = await probeOAuth();

  const endpointsToProbe = [
    {
      name: 'Ruleset Index',
      path: '/data/wow/ruleset/index',
      namespace: `dynamic-forever-${REGION}`,
      status: 'COMMUNITY_PROBED'
    },
    {
      name: 'Ruleset Detail (ID: 1 - JcJ)',
      path: `/data/wow/ruleset/1`,
      namespace: `dynamic-forever-${REGION}`,
      status: 'COMMUNITY_PROBED'
    },
    {
      name: 'Character Profile',
      path: `/profile/wow/character/${TEST_CHAR}`,
      namespace: `profile-forever-${REGION}`,
      status: 'COMMUNITY_PROBED'
    },
    {
      name: 'Character Equipment',
      path: `/profile/wow/character/${TEST_CHAR}/equipment`,
      namespace: `profile-forever-${REGION}`,
      status: 'COMMUNITY_PROBED'
    },
    {
      name: 'Character Statistics',
      path: `/profile/wow/character/${TEST_CHAR}/statistics`,
      namespace: `profile-forever-${REGION}`,
      status: 'COMMUNITY_PROBED'
    },
    {
      name: 'Character Specializations/Traits',
      path: `/profile/wow/character/${TEST_CHAR}/specializations`,
      namespace: `profile-forever-${REGION}`,
      status: 'PENDING_VALIDATION'
    },
    {
      name: 'Character Media',
      path: `/profile/wow/character/${TEST_CHAR}/character-media`,
      namespace: `profile-forever-${REGION}`,
      status: 'PENDING_VALIDATION'
    },
    {
      name: 'Guild Roster',
      path: `/data/wow/guild/${GUILD_SLUG}/roster`,
      namespace: `profile-forever-${REGION}`,
      status: 'COMMUNITY_PROBED'
    },
    {
      name: 'Guild Activity',
      path: `/data/wow/guild/${GUILD_SLUG}/activity`,
      namespace: `profile-forever-${REGION}`,
      status: 'PENDING_VALIDATION'
    }
  ];

  for (const ep of endpointsToProbe) {
    await probeEndpoint(ep.name, ep.path, ep.namespace, ep.status, token);
  }

  // Generate Report
  generateReport(token);
}

function generateReport(hasToken) {
  console.log('\nValidation Results Summary:');
  console.table(testResults.map(r => ({
    'Test Target': r.testName,
    'Classification': r.statusCategory,
    'HTTP': r.httpStatus,
    'Latency': `${r.latencyMs}ms`,
    'Outcome': r.success ? 'PASS' : (r.httpStatus === 'SKIPPED' ? 'AWAITING_CREDS' : 'FAIL'),
    'Notes': r.details.slice(0, 45)
  })));

  // Write markdown report
  const reportPath = path.join(__dirname, 'VALIDATION_REPORT.md');
  let md = `# BlazonGuild Battle.net API Integration Validation Report\n\n`;
  md += `**Execution Date:** ${new Date().toISOString()}\n`;
  md += `**Target:** World of Warcraft: Forever (Official)\n`;
  md += `**Region:** ${REGION.toUpperCase()} | **Ruleset:** ${RULESET_ID} | **Locale:** ${LOCALE}\n\n`;

  if (!hasToken) {
    md += `> [!NOTE]\n`;
    md += `> Integration probes are configured and ready. Set valid \`BLIZZARD_CLIENT_ID\` and \`BLIZZARD_CLIENT_SECRET\` in \`.env\` and execute \`npm run probe:api\` to execute live HTTP verification against Battle.net.\n\n`;
  }

  md += `## Endpoint Verification Matrix\n\n`;
  md += `| Target | Endpoint / Resource | Classification | HTTP Status | Latency | Outcome | Notes |\n`;
  md += `| :--- | :--- | :---: | :---: | :---: | :---: | :--- |\n`;

  for (const r of testResults) {
    const outcome = r.success ? 'PASS' : (r.httpStatus === 'SKIPPED' ? 'AWAITING_CREDS' : 'FAIL');
    md += `| **${r.testName}** | \`${r.endpoint}\` | \`${r.statusCategory}\` | \`${r.httpStatus}\` | ${r.latencyMs}ms | **${outcome}** | ${r.details} |\n`;
  }

  // Append sample schemas
  const successfulProbes = testResults.filter(r => r.samplePayload);
  if (successfulProbes.length > 0) {
    md += `\n## Sample Response Payloads & Field Schemas\n\n`;
    for (const sp of successfulProbes) {
      md += `### ${sp.testName}\n`;
      md += `\`\`\`json\n${JSON.stringify(sp.samplePayload, null, 2)}\n\`\`\`\n\n`;
    }
  }

  try {
    fs.writeFileSync(reportPath, md, 'utf8');
    console.log(`\nDetailed report written to: ${reportPath}`);
  } catch (e) {
    console.log(`\nNote: Terminal output complete. Report file write skipped (${e.message}).`);
  }
}

runValidationSuite();
