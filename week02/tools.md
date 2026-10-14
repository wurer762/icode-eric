# IaC tools comparison

| Tool | Agent? | Push/Pull | Declarative? | Language | Purpose |
|------|--------|-----------|--------------|----------|---------|
| Ansible | agentless (SSH) | push | mostly declarative | YAML | configuration |
| Terraform / OpenTofu | agentless (APIs) | push | declarative | HCL | provisioning |
| Chef | agent | pull | imperative | Ruby DSL | configuration |
| Puppet / OpenVox | agent | pull | declarative | Puppet DSL | configuration |
| Pulumi | agentless (APIs) | push | declarative (written in code) | Python, TypeScript, Go, C# | provisioning |
