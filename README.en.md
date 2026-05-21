# Security & Cloud Infrastructure Portfolio

This repository is a **portfolio and design comparison**, not a production SaaS product.

It demonstrates how cloud and AI agent placement should change with business context (hospitality brand, internal culture, risk).

## Projects

| Path | Focus |
|------|--------|
| [`AWS_log/`](AWS_log/) | CloudTrail / VPC Flow analysis with Athena |
| [`analysis_wireshark/`](analysis_wireshark/) | Offline egress monitoring for local LLM workloads |
| [`hotel_folder/`](hotel_folder/) | Hotel Type-B vs Type-A + internal infra comparison |

## Hotel stack (high level)

- **Type-B:** Traditional 3-tier + **Sentinel** (rule-based security on logs; AI for chat only)
- **Type-A:** Serverless + Bedrock Agent with **gates:** `interface` → Agent → `tools/reader` / `execution/reservation`

Start here: [`hotel_folder/STRUCTURE.md`](hotel_folder/STRUCTURE.md)

## Verify locally

```bash
cd hotel_folder
make test
make ci
```

## Demo

No public demo URL is hosted (cost and credentials). See [`hotel_folder/docs/PORTFOLIO_STRATEGY.md`](hotel_folder/docs/PORTFOLIO_STRATEGY.md).
