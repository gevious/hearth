#!/usr/bin/env node

import process from 'node:process';

const DEFAULT_MODEL = process.env.LOCAL_MODEL || process.env.OPENAI_MODEL || 'qwen3-coder:30b';
const BASE_URL = (process.env.OPENAI_BASE_URL || 'http://127.0.0.1:11434/v1').replace(/\/$/, '');
const API_KEY = process.env.OPENAI_API_KEY || 'ollama';
const ROLE_MODEL = {
  planner: process.env.PLANNER_MODEL || DEFAULT_MODEL,
  coder: process.env.CODER_MODEL || DEFAULT_MODEL,
  reviewer: process.env.REVIEWER_MODEL || DEFAULT_MODEL,
  tester: process.env.TESTER_MODEL || DEFAULT_MODEL,
};

function usage() {
  console.log(`Usage:
  agentarium plan <goal>
  agentarium run <goal>
  agentarium worker <role> <task>
  agentarium health

Environment:
  OPENAI_BASE_URL   (default: http://127.0.0.1:11434/v1)
  OPENAI_API_KEY    (default: ollama)
  LOCAL_MODEL       (default: qwen3-coder:30b)
  PLANNER_MODEL / CODER_MODEL / REVIEWER_MODEL / TESTER_MODEL
`);
}

function modelForRole(role) {
  return ROLE_MODEL[role] || DEFAULT_MODEL;
}

async function chat(messages, { model = DEFAULT_MODEL, temperature = 0.2 } = {}) {
  const res = await fetch(`${BASE_URL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${API_KEY}`,
    },
    body: JSON.stringify({
      model,
      temperature,
      messages,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`LLM request failed (${res.status}): ${body}`);
  }

  const data = await res.json();
  const out = data?.choices?.[0]?.message?.content;
  if (!out) {
    throw new Error('LLM returned no content');
  }
  return out.trim();
}

async function runWorker(role, task, context = '') {
  const system = [
    'You are part of a local coding-agent swarm.',
    `Your role: ${role}.`,
    'Return concise, actionable output with no fluff.',
    role === 'planner' ? 'Break goals into a numbered task plan with acceptance criteria.' : '',
    role === 'reviewer' ? 'Focus on defects, regressions, risks, and missing tests.' : '',
    role === 'tester' ? 'Design practical verification steps and edge cases.' : '',
  ]
    .filter(Boolean)
    .join(' ');

  return chat(
    [
      { role: 'system', content: system },
      {
        role: 'user',
        content: context ? `Context:\n${context}\n\nTask:\n${task}` : `Task:\n${task}`,
      },
    ],
    { model: modelForRole(role) }
  );
}

async function runPlan(goal) {
  return runWorker('planner', `Create an execution plan for:\n${goal}`);
}

async function runDelegated(goal) {
  const plan = await runPlan(goal);
  const coder = await runWorker('coder', `Execute this goal:\n${goal}`, `Plan:\n${plan}`);
  const reviewer = await runWorker(
    'reviewer',
    'Review the proposed solution and list concrete issues.',
    `Goal:\n${goal}\n\nProposed solution:\n${coder}`
  );
  const tester = await runWorker(
    'tester',
    'Define verification steps to validate this work.',
    `Goal:\n${goal}\n\nPlan:\n${plan}\n\nSolution:\n${coder}`
  );

  return { plan, coder, reviewer, tester };
}

async function health() {
  const response = await fetch(`${BASE_URL.replace(/\/v1$/, '')}/api/tags`);
  if (!response.ok) {
    throw new Error(`Ollama health failed (${response.status})`);
  }
  const json = await response.json();
  const names = (json.models || []).map((m) => m.name).slice(0, 8);
  return {
    baseUrl: BASE_URL,
    defaultModel: DEFAULT_MODEL,
    roleModels: ROLE_MODEL,
    modelsAvailable: names,
  };
}

async function main() {
  const [, , command, ...rest] = process.argv;

  if (!command || command === '--help' || command === '-h') {
    usage();
    process.exit(0);
  }

  try {
    switch (command) {
      case 'plan': {
        const goal = rest.join(' ').trim();
        if (!goal) throw new Error('Missing goal');
        console.log(await runPlan(goal));
        return;
      }
      case 'worker': {
        const role = (rest[0] || '').trim();
        const task = rest.slice(1).join(' ').trim();
        if (!role || !task) throw new Error('Usage: agentarium worker <role> <task>');
        console.log(await runWorker(role, task));
        return;
      }
      case 'run': {
        const goal = rest.join(' ').trim();
        if (!goal) throw new Error('Missing goal');
        const out = await runDelegated(goal);
        console.log(`# Plan\n${out.plan}\n\n# Coder\n${out.coder}\n\n# Reviewer\n${out.reviewer}\n\n# Tester\n${out.tester}`);
        return;
      }
      case 'health': {
        console.log(JSON.stringify(await health(), null, 2));
        return;
      }
      default:
        throw new Error(`Unknown command: ${command}`);
    }
  } catch (err) {
    console.error(String(err.message || err));
    process.exit(1);
  }
}

await main();
