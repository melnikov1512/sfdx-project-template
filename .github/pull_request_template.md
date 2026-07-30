<!-- Optional: add context not visible from the diff -->

## Type of Change

- [ ] Bug fix
- [ ] New feature / enhancement
- [ ] Refactor / cleanup
- [ ] CI / tooling / infrastructure
- [ ] Documentation
- [ ] Salesforce metadata change

## Related Tickets

<!-- Jira, Linear, or other task tracker links -->

---

## Security Self-Review

> For exceptions, reference a time-boxed issue per [RUNBOOK.md §12](RUNBOOK.md#12).

- [ ] No secrets, credentials, or PII in code, config, or test data
- [ ] Dependencies: no new High/Critical CVEs (`npm audit`)
- [ ] Apex: `with sharing` enforced; CRUD/FLS checked where applicable
- [ ] Access control: no unintentional guest/public access; permissions scoped minimally

---

## Testing

- [ ] `npm run validate` passes locally
- [ ] New or changed logic is covered by unit tests
- [ ] Relevant LWC tests updated / added
