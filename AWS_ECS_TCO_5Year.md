# ERPNext AWS ECS Fargate - 5-Year Total Cost of Ownership (TCO) Analysis

## Executive Summary
**Organization Size**: 2,000 users  
**Environments**: Development, SIT, UAT, Production + DR Options  
**Container Platform**: Amazon ECS with Fargate (Serverless Containers)  
**Region**: US-East-1 (Primary), US-West-2 (DR)  
**Exchange Rate**: 1 USD = 56 PHP (as of January 2025)

## Architecture Overview for 2,000 Users

### ECS Fargate Architecture Benefits
- **Serverless Containers**: No EC2 instances to manage
- **Automatic Scaling**: Built-in auto-scaling based on demand
- **Pay-per-use**: Only pay for actual vCPU and memory consumed
- **Zero Maintenance**: AWS manages all infrastructure
- **Enhanced Security**: Task-level isolation

### Production Environment Sizing (ECS Fargate)
- **Container Orchestration**: ECS with Fargate tasks
- **Database**: Amazon RDS MySQL (db.r5.2xlarge) Multi-AZ
- **Cache**: Amazon MemoryDB for Redis (3-node cluster)
- **Storage**: Amazon EFS (500GB) + S3 (2TB)
- **Network**: Multi-AZ VPC with AWS PrivateLink

### Disaster Recovery Options
#### Hot Standby (Active-Passive)
- **RPO**: < 5 minutes
- **RTO**: < 15 minutes
- **Cross-region replication for all components
- **Automated failover with Route 53

#### Warm Standby (Pilot Light)
- **RPO**: < 1 hour
- **RTO**: < 4 hours
- **Minimal infrastructure with scaling capability
- **Cost-optimized for recovery scenarios

---

## 1. Infrastructure Costs (Monthly)

### Development Environment

| Component | Specification | Monthly Cost (USD) | Monthly Cost (PHP) |
|-----------|--------------|-------------------|-------------------|
| **ECS Fargate Tasks** | | | |
| - Backend | 1 task (2 vCPU, 4GB) | $58 | ₱3,248 |
| - Frontend | 1 task (1 vCPU, 2GB) | $29 | ₱1,624 |
| - Workers | 2 tasks (1 vCPU, 2GB each) | $58 | ₱3,248 |
| - Scheduler | 1 task (0.5 vCPU, 1GB) | $15 | ₱840 |
| **Managed Services** | | | |
| RDS MySQL | db.t3.medium (Single-AZ) | $51 | ₱2,856 |
| MemoryDB Redis | 1 × db.t4g.small | $36 | ₱2,016 |
| ALB | 1 load balancer | $22 | ₱1,232 |
| EFS | 50GB | $15 | ₱840 |
| S3 | 100GB | $3 | ₱168 |
| NAT Gateway | 1 gateway | $45 | ₱2,520 |
| ECR | Container images (10GB) | $1 | ₱56 |
| CloudWatch | Basic monitoring | $10 | ₱560 |
| Data Transfer | ~100GB | $9 | ₱504 |
| **Subtotal** | | **$352** | **₱19,712** |

### SIT Environment

| Component | Specification | Monthly Cost (USD) | Monthly Cost (PHP) |
|-----------|--------------|-------------------|-------------------|
| **ECS Fargate Tasks** | | | |
| - Backend | 2 tasks (2 vCPU, 4GB each) | $116 | ₱6,496 |
| - Frontend | 2 tasks (1 vCPU, 2GB each) | $58 | ₱3,248 |
| - Workers | 3 tasks (2 vCPU, 4GB each) | $174 | ₱9,744 |
| - Scheduler | 1 task (1 vCPU, 2GB) | $29 | ₱1,624 |
| **Managed Services** | | | |
| RDS MySQL | db.r5.large (Single-AZ) | $115 | ₱6,440 |
| MemoryDB Redis | 2 × db.t4g.small | $72 | ₱4,032 |
| ALB | 1 load balancer | $22 | ₱1,232 |
| EFS | 100GB | $30 | ₱1,680 |
| S3 | 500GB | $12 | ₱672 |
| NAT Gateway | 1 gateway | $45 | ₱2,520 |
| ECR | Container images (20GB) | $2 | ₱112 |
| CloudWatch | Standard monitoring | $25 | ₱1,400 |
| Data Transfer | ~200GB | $18 | ₱1,008 |
| **Subtotal** | | **$718** | **₱40,208** |

### UAT Environment

| Component | Specification | Monthly Cost (USD) | Monthly Cost (PHP) |
|-----------|--------------|-------------------|-------------------|
| **ECS Fargate Tasks** | | | |
| - Backend | 3 tasks (4 vCPU, 8GB each) | $348 | ₱19,488 |
| - Frontend | 2 tasks (2 vCPU, 4GB each) | $116 | ₱6,496 |
| - Workers | 4 tasks (2 vCPU, 4GB each) | $232 | ₱12,992 |
| - Scheduler | 2 tasks (1 vCPU, 2GB each) | $58 | ₱3,248 |
| - WebSocket | 2 tasks (1 vCPU, 2GB each) | $58 | ₱3,248 |
| **Managed Services** | | | |
| RDS MySQL | db.r5.xlarge (Multi-AZ) | $460 | ₱25,760 |
| MemoryDB Redis | 2 × db.r6g.large | $180 | ₱10,080 |
| ALB | 1 load balancer | $22 | ₱1,232 |
| EFS | 200GB | $60 | ₱3,360 |
| S3 | 1TB | $23 | ₱1,288 |
| NAT Gateway | 2 gateways (HA) | $90 | ₱5,040 |
| ECR | Container images (30GB) | $3 | ₱168 |
| CloudWatch | Enhanced monitoring | $50 | ₱2,800 |
| Secrets Manager | 20 secrets | $8 | ₱448 |
| Data Transfer | ~500GB | $45 | ₱2,520 |
| **Subtotal** | | **$1,743** | **₱97,608** |

### Production Environment

| Component | Specification | Monthly Cost (USD) | Monthly Cost (PHP) |
|-----------|--------------|-------------------|-------------------|
| **ECS Fargate Tasks** | | | |
| - Backend | 6 tasks (4 vCPU, 16GB each) | $1,044 | ₱58,464 |
| - Frontend | 4 tasks (2 vCPU, 4GB each) | $232 | ₱12,992 |
| - Workers (Default) | 4 tasks (4 vCPU, 8GB each) | $464 | ₱25,984 |
| - Workers (Long) | 3 tasks (4 vCPU, 8GB each) | $348 | ₱19,488 |
| - Workers (Short) | 3 tasks (2 vCPU, 4GB each) | $174 | ₱9,744 |
| - Scheduler | 2 tasks (2 vCPU, 4GB each) | $116 | ₱6,496 |
| - WebSocket | 3 tasks (2 vCPU, 4GB each) | $174 | ₱9,744 |
| **Managed Services** | | | |
| RDS MySQL | db.r5.2xlarge (Multi-AZ) | $920 | ₱51,520 |
| RDS Read Replica | db.r5.xlarge | $230 | ₱12,880 |
| MemoryDB Redis | 3 × db.r6g.xlarge | $810 | ₱45,360 |
| ALB | 2 load balancers (HA) | $44 | ₱2,464 |
| EFS | 500GB | $150 | ₱8,400 |
| S3 | 2TB | $46 | ₱2,576 |
| NAT Gateway | 3 gateways (Multi-AZ) | $135 | ₱7,560 |
| CloudFront CDN | Standard distribution | $50 | ₱2,800 |
| ECR | Container images (50GB) | $5 | ₱280 |
| CloudWatch | Detailed monitoring | $100 | ₱5,600 |
| Container Insights | ECS monitoring | $50 | ₱2,800 |
| X-Ray | Distributed tracing | $25 | ₱1,400 |
| Secrets Manager | 50 secrets | $20 | ₱1,120 |
| Systems Manager | Parameter Store | $10 | ₱560 |
| AWS WAF | Web application firewall | $35 | ₱1,960 |
| AWS Shield Standard | DDoS protection | $0 | ₱0 |
| Data Transfer | ~2TB | $180 | ₱10,080 |
| **Subtotal** | | **$5,362** | **₱300,272** |

### Disaster Recovery - Hot Standby (Active-Passive)

| Component | Specification | Monthly Cost (USD) | Monthly Cost (PHP) |
|-----------|--------------|-------------------|-------------------|
| **ECS Fargate Tasks** | | | |
| - Backend | 6 tasks (4 vCPU, 16GB each) | $1,044 | ₱58,464 |
| - Frontend | 4 tasks (2 vCPU, 4GB each) | $232 | ₱12,992 |
| - Workers (All) | 10 tasks (mixed sizing) | $986 | ₱55,216 |
| - Scheduler | 2 tasks (2 vCPU, 4GB each) | $116 | ₱6,496 |
| - WebSocket | 3 tasks (2 vCPU, 4GB each) | $174 | ₱9,744 |
| **Managed Services** | | | |
| RDS MySQL | db.r5.2xlarge (Multi-AZ, Read Replica) | $920 | ₱51,520 |
| MemoryDB Redis | 3 × db.r6g.xlarge | $810 | ₱45,360 |
| ALB | 2 load balancers | $44 | ₱2,464 |
| EFS | 500GB (Cross-region replication) | $300 | ₱16,800 |
| S3 | 2TB (Cross-region replication) | $92 | ₱5,152 |
| NAT Gateway | 3 gateways | $135 | ₱7,560 |
| CloudFront CDN | Shared with production | $0 | ₱0 |
| ECR | Cross-region replication | $10 | ₱560 |
| Cross-Region Data Transfer | Database & storage sync | $500 | ₱28,000 |
| Route 53 Health Checks | Failover routing | $50 | ₱2,800 |
| CloudWatch | Cross-region monitoring | $50 | ₱2,800 |
| **Subtotal** | | **$5,463** | **₱305,928** |

### Disaster Recovery - Warm Standby (Pilot Light)

| Component | Specification | Monthly Cost (USD) | Monthly Cost (PHP) |
|-----------|--------------|-------------------|-------------------|
| **ECS Fargate Tasks** | | | |
| - Backend | 2 tasks (2 vCPU, 4GB each) | $116 | ₱6,496 |
| - Frontend | 1 task (1 vCPU, 2GB) | $29 | ₱1,624 |
| - Workers | 2 tasks (2 vCPU, 4GB each) | $116 | ₱6,496 |
| - Scheduler | 1 task (1 vCPU, 2GB) | $29 | ₱1,624 |
| **Managed Services** | | | |
| RDS MySQL | db.t3.large (Single-AZ, Read Replica) | $200 | ₱11,200 |
| MemoryDB Redis | 1 × db.t4g.medium | $72 | ₱4,032 |
| ALB | 1 load balancer | $22 | ₱1,232 |
| EFS | 500GB (Daily sync) | $150 | ₱8,400 |
| S3 | 2TB backup storage | $46 | ₱2,576 |
| NAT Gateway | 1 gateway | $45 | ₱2,520 |
| ECR | Minimal replication | $2 | ₱112 |
| Lambda | Scaling automation | $20 | ₱1,120 |
| EventBridge | Scheduled tasks | $5 | ₱280 |
| AWS Backup | Automated backups | $30 | ₱1,680 |
| **Subtotal** | | **$882** | **₱49,392** |

### **Total Monthly Infrastructure Costs**

#### Option 1: With Hot DR
| Environment | Monthly Cost (USD) | Monthly Cost (PHP) |
|------------|-------------------|-------------------|
| Development | $352 | ₱19,712 |
| SIT | $718 | ₱40,208 |
| UAT | $1,743 | ₱97,608 |
| Production | $5,362 | ₱300,272 |
| DR (Hot) | $5,463 | ₱305,928 |
| **TOTAL** | **$13,638** | **₱763,728** |

#### Option 2: With Warm DR
| Environment | Monthly Cost (USD) | Monthly Cost (PHP) |
|------------|-------------------|-------------------|
| Development | $352 | ₱19,712 |
| SIT | $718 | ₱40,208 |
| UAT | $1,743 | ₱97,608 |
| Production | $5,362 | ₱300,272 |
| DR (Warm) | $882 | ₱49,392 |
| **TOTAL** | **$9,057** | **₱507,192** |

---

## 2. Operational Costs (Annual)

### Personnel Costs (Reduced with ECS Fargate)
| Role | FTE | Annual Cost (USD) | Annual Cost (PHP) |
|------|-----|------------------|------------------|
| Cloud Architect | 0.5 | $75,000 | ₱4,200,000 |
| DevOps Engineers | 2 | $240,000 | ₱13,440,000 |
| Database Administrator | 0.5 | $55,000 | ₱3,080,000 |
| Security Engineer | 0.5 | $65,000 | ₱3,640,000 |
| Support Team (Business hours) | 2 | $120,000 | ₱6,720,000 |
| **Subtotal** | 5.5 | **$555,000** | **₱31,080,000** |

*Note: ECS Fargate requires 50% less operational staff compared to EC2-based deployments*

### AWS Support & Services
| Service | Annual Cost (USD) | Annual Cost (PHP) |
|---------|------------------|------------------|
| AWS Business Support (10% of spend) | $16,366 | ₱916,496 |
| Third-party Monitoring (Datadog/New Relic) | $18,000 | ₱1,008,000 |
| Security Audit (Quarterly) | $20,000 | ₱1,120,000 |
| Compliance Certifications | $15,000 | ₱840,000 |
| **Subtotal** | **$69,366** | **₱3,884,496** |

### Training & Certification
| Item | Annual Cost (USD) | Annual Cost (PHP) |
|------|------------------|------------------|
| AWS Training Programs | $10,000 | ₱560,000 |
| ECS/Fargate Specialization | $5,000 | ₱280,000 |
| Conferences & Workshops | $10,000 | ₱560,000 |
| **Subtotal** | **$25,000** | **₱1,400,000** |

---

## 3. Software Licensing Costs (Annual)

| Software | Annual Cost (USD) | Annual Cost (PHP) |
|----------|------------------|------------------|
| ERPNext Enterprise Support | $30,000 | ₱1,680,000 |
| Container Security (Snyk/Twistlock) | $12,000 | ₱672,000 |
| APM Tools (Datadog/New Relic) | $15,000 | ₱840,000 |
| Log Management (ELK/Splunk) | $10,000 | ₱560,000 |
| CI/CD Pipeline (GitLab/Jenkins) | $8,000 | ₱448,000 |
| **Subtotal** | **$75,000** | **₱4,200,000** |

---

## 4. Migration & Implementation Costs (One-time, Year 1)

| Activity | Cost (USD) | Cost (PHP) |
|----------|------------|------------|
| Assessment & Planning | $20,000 | ₱1,120,000 |
| Containerization of ERPNext | $30,000 | ₱1,680,000 |
| ECS Architecture Design | $25,000 | ₱1,400,000 |
| Data Migration | $40,000 | ₱2,240,000 |
| Testing & Validation | $25,000 | ₱1,400,000 |
| Training & Knowledge Transfer | $20,000 | ₱1,120,000 |
| Go-Live Support (3 months) | $30,000 | ₱1,680,000 |
| **Total** | **$190,000** | **₱10,640,000** |

---

## 5. Cost Optimization Strategies

### Fargate Spot Instances (70% Savings for Non-Critical Workloads)
| Environment | Standard Cost/Month | Spot Cost/Month | Savings/Month |
|------------|-------------------|-----------------|---------------|
| Development | $160 | $48 | $112 |
| SIT | $377 | $113 | $264 |
| UAT (partial) | $406 | $122 | $284 |
| **Total Monthly Savings** | | | **$660** |

### Savings Plans (3-Year Commitment)
| Service | Standard Cost/Year | With Savings Plan | Annual Savings |
|---------|-------------------|-------------------|----------------|
| Fargate Compute | $60,000 | $42,000 | $18,000 |
| RDS Instances | $25,000 | $15,000 | $10,000 |
| **Total Annual Savings** | | | **$28,000** |

### Auto-Scaling Optimization
- **Off-peak scaling**: Reduce tasks by 60% during nights/weekends
- **Estimated savings**: $1,200/month ($14,400/year)

---

## 6. Five-Year Total Cost of Ownership Summary

### Scenario 1: With Hot DR

#### Year 1 (with Migration)
| Category | Cost (USD) | Cost (PHP) |
|----------|------------|------------|
| Infrastructure (12 months) | $163,656 | ₱9,164,736 |
| Operations | $649,366 | ₱36,364,496 |
| Software Licensing | $75,000 | ₱4,200,000 |
| Migration (one-time) | $190,000 | ₱10,640,000 |
| **Year 1 Total** | **$1,078,022** | **₱60,369,232** |

#### Years 2-5 (Annual)
| Category | Cost (USD) | Cost (PHP) |
|----------|------------|------------|
| Infrastructure | $163,656 | ₱9,164,736 |
| Operations | $649,366 | ₱36,364,496 |
| Software Licensing | $75,000 | ₱4,200,000 |
| **Annual Total** | **$888,022** | **₱49,729,232** |

#### 5-Year Total with Hot DR
| Period | Cost (USD) | Cost (PHP) |
|--------|------------|------------|
| Year 1 | $1,078,022 | ₱60,369,232 |
| Year 2 | $888,022 | ₱49,729,232 |
| Year 3 | $888,022 | ₱49,729,232 |
| Year 4 | $888,022 | ₱49,729,232 |
| Year 5 | $888,022 | ₱49,729,232 |
| **5-Year Total** | **$4,630,110** | **₱259,286,160** |
| **Average Annual Cost** | **$926,022** | **₱51,857,232** |
| **Cost Per User Per Month** | **$38.58** | **₱2,161** |

### Scenario 2: With Warm DR

#### Year 1 (with Migration)
| Category | Cost (USD) | Cost (PHP) |
|----------|------------|------------|
| Infrastructure (12 months) | $108,684 | ₱6,086,304 |
| Operations | $649,366 | ₱36,364,496 |
| Software Licensing | $75,000 | ₱4,200,000 |
| Migration (one-time) | $190,000 | ₱10,640,000 |
| **Year 1 Total** | **$1,023,050** | **₱57,290,800** |

#### Years 2-5 (Annual)
| Category | Cost (USD) | Cost (PHP) |
|----------|------------|------------|
| Infrastructure | $108,684 | ₱6,086,304 |
| Operations | $649,366 | ₱36,364,496 |
| Software Licensing | $75,000 | ₱4,200,000 |
| **Annual Total** | **$833,050** | **₱46,650,800** |

#### 5-Year Total with Warm DR
| Period | Cost (USD) | Cost (PHP) |
|--------|------------|------------|
| Year 1 | $1,023,050 | ₱57,290,800 |
| Year 2 | $833,050 | ₱46,650,800 |
| Year 3 | $833,050 | ₱46,650,800 |
| Year 4 | $833,050 | ₱46,650,800 |
| Year 5 | $833,050 | ₱46,650,800 |
| **5-Year Total** | **$4,355,250** | **₱243,894,000** |
| **Average Annual Cost** | **$871,050** | **₱48,778,800** |
| **Cost Per User Per Month** | **$36.29** | **₱2,032** |

---

## 7. Five-Year TCO with Full Optimization

### Applied Optimizations
1. **Fargate Spot** for Dev/SIT/UAT: -$7,920/year
2. **Savings Plans**: -$28,000/year
3. **Auto-scaling**: -$14,400/year
4. **Reserved Instances** for RDS: -$15,000/year
5. **S3 Intelligent Tiering**: -$2,400/year

### Optimized 5-Year TCO
| Scenario | Standard TCO | Optimized TCO | Total Savings |
|----------|--------------|---------------|---------------|
| With Hot DR | $4,630,110 | $4,291,510 | $338,600 |
| With Warm DR | $4,355,250 | $4,016,650 | $338,600 |

**Optimized Cost Per User Per Month**:
- Hot DR: $35.76 (₱2,003)
- Warm DR: $33.47 (₱1,874)

---

## 8. Cost Breakdown by Category (5-Year)

### With Warm DR (Recommended)
| Category | 5-Year Total (USD) | 5-Year Total (PHP) | Percentage |
|----------|-------------------|-------------------|------------|
| Infrastructure | $543,420 | ₱30,431,520 | 12.5% |
| ECS Fargate Compute | $1,200,000 | ₱67,200,000 | 27.6% |
| Managed Services (RDS/Redis) | $800,000 | ₱44,800,000 | 18.4% |
| Personnel | $2,775,000 | ₱155,400,000 | 63.7% |
| AWS Support | $346,830 | ₱19,422,480 | 8.0% |
| Software Licensing | $375,000 | ₱21,000,000 | 8.6% |
| Migration | $190,000 | ₱10,640,000 | 4.4% |
| Training | $125,000 | ₱7,000,000 | 2.9% |
| **Total** | **$4,355,250** | **₱243,894,000** | 100% |

---

## 9. ECS Fargate vs EKS Comparison

| Factor | ECS Fargate | EKS | Winner |
|--------|-------------|-----|--------|
| **Infrastructure Cost** | $9,057/month | $7,551/month | EKS |
| **Operational Overhead** | Very Low | Medium | ECS |
| **Personnel Required** | 5.5 FTE | 8 FTE | ECS |
| **Time to Deploy** | 2-3 weeks | 4-6 weeks | ECS |
| **Scaling Speed** | < 1 minute | 2-5 minutes | ECS |
| **Maintenance** | Zero | Regular | ECS |
| **5-Year TCO (Warm DR)** | $4,355,250 | $4,810,710 | ECS |

**Recommendation**: ECS Fargate is 9.5% cheaper over 5 years and requires 45% less operational staff.

---

## 10. ROI Analysis

### Tangible Benefits vs On-Premise
| Benefit | Annual Value | 5-Year Value |
|---------|-------------|--------------|
| Hardware refresh avoided | $150,000 | $750,000 |
| Data center costs eliminated | $100,000 | $500,000 |
| Power & cooling savings | $40,000 | $200,000 |
| Reduced IT staff (3 FTE) | $180,000 | $900,000 |
| Downtime reduction (99.99% SLA) | $80,000 | $400,000 |
| **Total Tangible Savings** | **$550,000** | **$2,750,000** |

### Intangible Benefits
- **Deployment Speed**: 75% faster than traditional infrastructure
- **Scalability**: Handle 5x traffic spikes without pre-provisioning
- **Innovation**: Deploy features 60% faster with CI/CD
- **Security**: Enterprise-grade security with compliance certifications
- **Global Reach**: Deploy to new regions in hours

### Break-Even Analysis
- **Investment**: $1,023,050 (Year 1 with Warm DR)
- **Annual Savings**: $550,000
- **Break-even Point**: 1.86 years
- **5-Year Net Benefit**: $1,726,950

---

## 11. Implementation Roadmap

### Phase 1: Foundation (Months 1-2)
- AWS account setup and landing zone
- Network architecture (VPC, subnets, security)
- ECS cluster creation and configuration
- Container registry (ECR) setup
- **Cost**: $40,000

### Phase 2: Containerization (Month 2-3)
- ERPNext containerization
- Docker image optimization
- CI/CD pipeline setup
- Development environment deployment
- **Cost**: $50,000

### Phase 3: Non-Production (Months 3-4)
- SIT environment deployment
- UAT environment deployment
- Testing and validation
- Performance optimization
- **Cost**: $40,000

### Phase 4: Production (Months 4-5)
- Production deployment
- Data migration
- DR site setup
- Load testing
- **Cost**: $40,000

### Phase 5: Optimization (Month 6)
- Auto-scaling configuration
- Cost optimization
- Monitoring enhancement
- Documentation
- **Cost**: $20,000

---

## 12. Risk Mitigation Strategies

### Technical Risks
| Risk | Mitigation | Cost Impact |
|------|------------|-------------|
| Container failures | ECS service auto-recovery | Included |
| Data loss | Automated backups, point-in-time recovery | Included |
| Performance issues | Auto-scaling, performance insights | +$100/month |
| Security breach | WAF, container scanning, secrets management | +$200/month |
| Vendor lock-in | Container portability, standard tools | None |

### Financial Risks
| Risk | Mitigation |
|------|------------|
| Budget overrun | Cost alerts, budgets, reserved capacity |
| Unexpected growth | Elastic scaling, no upfront costs |
| Exchange rate fluctuation | USD budgeting, currency hedging |

---

## 13. Recommendations

### For 2,000 Users Organization

1. **Primary Recommendation**: 
   - **ECS Fargate with Warm DR**
   - 5-year TCO: $4,355,250 (₱243,894,000)
   - Monthly cost: $9,057 (₱507,192)
   - Cost per user: $36.29/month (₱2,032)

2. **Why ECS Fargate over EKS**:
   - 45% less operational staff required
   - Zero infrastructure management
   - Faster deployment and scaling
   - Lower total cost of ownership
   - Simpler disaster recovery

3. **Optimization Priority**:
   - Implement Fargate Spot immediately (30% savings on non-prod)
   - Purchase 3-year Savings Plans (save $28,000/year)
   - Configure aggressive auto-scaling (save $14,400/year)
   - Use S3 Intelligent Tiering (save $2,400/year)

4. **Growth Considerations**:
   - Architecture scales linearly to 10,000 users
   - No infrastructure changes needed for 3x growth
   - Consider multi-region deployment at 5,000+ users

5. **Success Factors**:
   - Invest in containerization expertise
   - Implement comprehensive monitoring from day 1
   - Automate everything possible
   - Regular cost optimization reviews (monthly)

---

## Appendix A: Detailed Assumptions

### Technical Assumptions
- 2,000 total users, 500-800 concurrent
- Average 40 transactions per user per day
- 500GB initial data with 30% annual growth
- 99.9% uptime requirement for production
- Peak usage 2.5x average during month-end

### Financial Assumptions
- USD to PHP exchange rate: 56.00
- Annual inflation: Not included in calculations
- AWS price stability assumed
- No major architectural changes over 5 years

### ECS Fargate Specific
- Task startup time: 30-60 seconds
- Memory/CPU ratio: 1:2 (1 vCPU per 2GB RAM minimum)
- Container image size: <1GB per service
- Auto-scaling response time: <1 minute

---

## Appendix B: Service Sizing Details

### Production Task Specifications
| Service | vCPU | Memory | Count | Purpose |
|---------|------|--------|-------|---------|
| Backend | 4 | 16GB | 6 | API & business logic |
| Frontend | 2 | 4GB | 4 | Static assets & UI |
| Worker-Default | 4 | 8GB | 4 | Standard jobs |
| Worker-Long | 4 | 8GB | 3 | Long-running jobs |
| Worker-Short | 2 | 4GB | 3 | Quick jobs |
| Scheduler | 2 | 4GB | 2 | Cron tasks |
| WebSocket | 2 | 4GB | 3 | Real-time features |

### Database Sizing Justification
- **RDS MySQL**: db.r5.2xlarge provides 8 vCPU, 64GB RAM
- Supports 2,000 connections, 10,000 IOPS
- Multi-AZ for 99.95% availability
- Read replica for reporting workloads

### Redis Cluster Configuration
- **MemoryDB**: 3 nodes × db.r6g.xlarge
- 100,000+ operations per second
- 99.99% durability with AOF persistence
- Multi-AZ deployment

---

**Note**: All prices are estimates based on AWS pricing as of January 2025. Actual costs may vary based on usage patterns, AWS price changes, and negotiated enterprise discounts. Consider engaging AWS sales for Enterprise Agreements for additional 15-25% discounts on committed spend over $500K annually.

**Final Recommendation**: ECS Fargate offers the best balance of cost, simplicity, and reliability for a 2,000-user ERPNext deployment, with a 5-year TCO of $4.36M (₱244M) including disaster recovery.