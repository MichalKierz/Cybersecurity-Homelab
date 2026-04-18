# Lab 01: Cloud Security Configuration Assessment

## Introduction

The purpose of this lab was to practice a basic cloud security configuration assessment. Instead of deploying resources to a real cloud environment, two local Infrastructure as Code files were prepared in Terraform: the first contained an intentionally insecure configuration, while the second presented its corrected version after remediation.

The analysis was performed using Checkov running locally on an Ubuntu server. This made it possible to verify whether common configuration mistakes could be detected before the infrastructure was deployed. This workflow reflects the shift-left security approach well, where security issues are identified during the configuration stage rather than only after resources are exposed in a production environment.

As part of the exercise, a scenario was prepared covering two main areas of risk:

- a publicly accessible and weakly secured S3 bucket,
- an overly permissive network rule in a security group.

A scan of the vulnerable version was then performed, the most important issues were remediated, and a second comparative scan was run.

## Environment and Tools

- Operating system: Ubuntu Server
- Lab type: local IaC analysis, without creating a cloud account
- Scanning tool: Checkov
- Configuration format: Terraform (`.tf`)
- Analyzed files:
  - `before_main.tf`
  - `after_main.tf`
- Saved outputs:
  - `before_checkov_response.txt`
  - `after_checkov_response.txt`

## Lab Assumptions

The goal was not to bring the scan to a perfect `0 failed` state, but to demonstrate a practical workflow:

1. preparing an insecure configuration,
2. running a baseline scan,
3. identifying the most significant risks,
4. correcting the configuration,
5. running the scan again and comparing the results.

This approach better reflects real cloud security work than mechanically removing all possible findings without prioritization.

## 1. Vulnerable Version: Analysis of the `before_main.tf` Configuration

The first Terraform file was intentionally built in an insecure way. It contained an S3 bucket with public read access and a public access block fully set to `false`. In addition, a security group was created allowing SSH traffic from `0.0.0.0/0`, as well as unrestricted outbound traffic without meaningful limitations.

The most important issues in the initial version were as follows:

- public read access to the S3 bucket,
- lack of effective public access blocking for the bucket,
- no versioning,
- no default encryption using KMS,
- port 22 open to the entire Internet,
- overly broad outbound traffic from the security group.

At this stage, the configuration accurately reflected common mistakes found in test environments or poorly prepared IaC projects, where the priority is to launch the resource quickly rather than secure it properly.

## 2. Result of the First Checkov Scan

After running Checkov against the `before` version, the following result was obtained:

- `Passed checks: 10`
- `Failed checks: 15`
- `Skipped checks: 0`

The most important findings concerned two areas.

### 2.1 Risks Related to the S3 Bucket

Checkov detected that the bucket was publicly readable, did not have properly enabled public access blocking mechanisms, did not have versioning, and did not use default KMS encryption. In practice, such a configuration increases the risk of accidental data exposure and makes it harder to recover or protect objects after unauthorized modification.

Particularly important findings included:

- `CKV_AWS_20` - public read access to the bucket,
- `CKV_AWS_53`, `CKV_AWS_54`, `CKV_AWS_55`, `CKV_AWS_56` - lack of effective `public access block` settings,
- `CKV_AWS_21` - versioning not enabled,
- `CKV_AWS_145` - no default KMS encryption.

### 2.2 Risks Related to Network Control

The second group of issues involved overly broad security group rules. Both SSH access open to the entire Internet and unrestricted outbound traffic were detected.

The most important findings in this area were:

- `CKV_AWS_24` - port 22 accessible from `0.0.0.0/0`,
- `CKV_AWS_382` - unrestricted outbound traffic.

The very first scan therefore showed that even a simple local Terraform file can contain configurations that would represent real security risks in an actual cloud environment.

## 3. Remediation and Preparation of the `after_main.tf` Version

In the second part of the lab, a corrected version of the configuration was prepared. The goal was not to implement full production-grade hardening, but to remove the most important and most obvious security issues.

The following changes were introduced in `after_main.tf`:

- a KMS key with rotation enabled was added,
- versioning was enabled for the S3 bucket,
- default bucket encryption using `aws:kms` was configured,
- all `public access block` settings were enabled,
- the public nature of the bucket was removed,
- SSH traffic was restricted to the `10.0.0.0/24` network,
- outbound traffic was narrowed to HTTPS connections within the internal network.

As a result, the corrected version focused on remediating the issues with the greatest security impact, rather than fully refining every possible additional mechanism.

## 4. Result of the Second Checkov Scan

After running Checkov against the `after` version, a clearly improved result was obtained:

- `Passed checks: 21`
- `Failed checks: 6`
- `Skipped checks: 0`

The most important observation is that all major problems targeted for remediation disappeared. Checkov no longer reported:

- public read access to the bucket,
- disabled public access block,
- missing versioning,
- missing KMS encryption,
- SSH open to the entire Internet,
- unrestricted outbound traffic to the outside world.

This means that the basic security layer was successfully improved.

## 5. Remaining Findings After Remediation

After the fixes, 6 findings still remained in the scan. These concerned more advanced maturity and hardening mechanisms rather than basic, critical configuration errors.

The remaining findings included, among others:

- no event notifications for S3,
- no lifecycle configuration,
- no access logging for the bucket,
- no cross-region replication,
- no explicitly defined KMS key policy,
- a security group not attached to a real resource.

In the context of this lab, they were left intentionally. The purpose of the exercise was to demonstrate the process of security assessment and remediation of the most important risks, not to build a complete production-ready infrastructure template.

## 6. Comparison of the State Before and After Remediation

The shortest summary of the lab can be presented as follows:

Before remediation - Passed 10 - Failed 15  
After remediation - Passed 21 - Failed 6

This result shows that even simple local IaC analysis makes it possible to quickly detect and reduce the most important security issues before resources are deployed to the cloud.

## Module Conclusions

- A local lab without a cloud account makes it possible to practice a real IaC security assessment workflow.
- Checkov works well as a tool for detecting basic configuration mistakes before infrastructure deployment.
- The greatest value comes not from the findings list itself, but from conscious prioritization and remediation of the most important issues.
- In this exercise, the most significant risks involved public S3 access, lack of bucket protection, and overly broad network exposure.
- Remediation reduced the number of failures from 15 to 6 and clearly increased the number of passed security checks.
- The remaining findings are more related to advanced hardening and can serve as the basis for a more difficult follow-up lab.
