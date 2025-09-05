# ERPNext AWS ECS Fargate - 5-Year Total Cost of Ownership (TCO) Analysis

## Executive Summary
**Organization Size**: 1,000 users  
**Environments**: Development, SIT, UAT, Production + DR (Hot Standby & Warm Options)  
**Container Platform**: Amazon ECS with AWS Fargate  
**Region**: US-East-1 (Primary), US-West-2 (DR)  
**Exchange Rate**: 1 USD = 56.50 PHP (as of January 2025)

## Architecture Overview for 1,000 Users

### Production Environment Sizing
- **Container Orchestration**: ECS with Fargate (serverless containers)
- **Database**: RDS MySQL (db.r5.xlarge) Multi-AZ with read replica
- **Cache**: Amazon MemoryDB (2 nodes, db.r6g.large)
- **Storage**: Amazon EFS (250GB) + S3 (1TB)
- **Network**: Multi-AZ VPC with AWS PrivateLink

### Disaster Recovery Options
#### Hot Standby (Active-Passive)
- **RPO**: < 5 minutes
- **RTO**: < 30 minutes
- **Cross-region replication for all data stores
- **Active-passive configuration with automated failover

#### Warm Standby (Pilot Light)
- **RPO**: < 1 hour
- **RTO**: < 4 hours
- **Minimal infrastructure with rapid scaling capability
- **Cost-optimized for recovery scenarios

---

## 1. Infrastructure Costs (Monthly)

### Development Environment
| Component | Specification | Monthly Cost (USD) | Monthly Cost (PHP) |
|-----------|--------------|-------------------|-------------------|
| **ECS Fargate Tasks** | | | |
| - Backend | 1 task (1 vCPU, 2GB) | $29 | ₱1,639 |
| - Frontend | 1 task (0.5 vCPU, 1GB) | $15 | ₱848 |
| - Workers | 1 task (1 vCPU, 2GB) | $29 | ₱1,639 |
| - Scheduler | 1 task (0.25 vCPU, 0.5GB) | $7 | ₱396 |
| **Managed Services** | | | |
| RDS MySQL | db.t3.small (Single-AZ) | $25 | ₱1,413 |
| MemoryDB Redis | 1 × db.t4g.micro | $12 | ₱678 |
| ALB | 1 load balancer | $22 | ₱1,243 |
| EFS | 25GB | $8 | ₱452 |
| S3 | 50GB | $1 | ₱57 |
| NAT Gateway | 1 gateway | $45 | ₱2,543 |
| ECR | Container images (5GB) | $1 | ₱57 |
| CloudWatch | Basic monitoring | $5 | ₱283 |
| Data Transfer | ~50GB | $5 | ₱283 |
| **Subtotal** | | **$204** | **₱11,526** |

### SIT Environment
| Component | Specification | Monthly Cost (USD) | Monthly Cost (PHP) |
|-----------|--------------|-------------------|-------------------|
| **ECS Fargate Tasks** | | | |
| - Backend | 2 tasks (1 vCPU, 2GB each) | $58 | ₱3,277 |
| - Frontend | 1 task (1 vCPU, 2GB) | $29 | ₱1,639 |
| - Workers | 2 tasks (1 vCPU, 2GB each) | $58 | ₱3,277 |
| - Scheduler | 1 task (0.5 vCPU, 1GB) | $15 | ₱848 |
| **Managed Services** | | | |
| RDS MySQL | db.t3.medium (Single-AZ) | $51 | ₱2,882 |
| MemoryDB Redis | 1 × db.t4g.small | $25 | ₱1,413 |
| ALB | 1 load balancer | $22 | ₱1,243 |
| EFS | 50GB | $15 | ₱848 |
| S3 | 200GB | $5 | ₱283 |
| NAT Gateway | 1 gateway | $45 | ₱2,543 |
| ECR | Container images (10GB) | $1 | ₱57 |
| CloudWatch | Standard monitoring | $15 | ₱848 |
| Data Transfer | ~100GB | $9 | ₱509 |
| **Subtotal** | | **$348** | **₱19,664** |

### UAT Environment
| Component | Specification | Monthly Cost (USD) | Monthly Cost (PHP) |
|-----------|--------------|-------------------|-------------------|
| **ECS Fargate Tasks** | | | |
| - Backend | 2 tasks (2 vCPU, 4GB each) | $116 | ₱6,554 |
| - Frontend | 2 tasks (1 vCPU, 2GB each) | $58 | ₱3,277 |
| - Workers | 3 tasks (1 vCPU, 2GB each) | $87 | ₱4,916 |
| - Scheduler | 1 task (1 vCPU, 2GB) | $29 | ₱1,639 |
| - WebSocket | 1 task (1 vCPU, 2GB) | $29 | ₱1,639 |
| **Managed Services** | | | |
| RDS MySQL | db.r5.large (Single-AZ) | $115 | ₱6,498 |
| MemoryDB Redis | 1 × db.r6g.large | $90 | ₱5,085 |
| ALB | 1 load balancer | $22 | ₱1,243 |
| EFS | 100GB | $30 | ₱1,695 |
| S3 | 500GB | $12 | ₱678 |
| NAT Gateway | 2 gateways (HA) | $90 | ₱5,085 |
| ECR | Container images (15GB) | $2 | ₱113 |
| CloudWatch | Enhanced monitoring | $30 | ₱1,695 |
| Secrets Manager | 10 secrets | $4 | ₱226 |
| Data Transfer | ~300GB | $27 | ₱1,526 |
| **Subtotal** | | **$741** | **₱41,867** |

### Production Environment
| Component | Specification | Monthly Cost (USD) | Monthly Cost (PHP) |
|-----------|--------------|-------------------|-------------------|
| **ECS Fargate Tasks** | | | |
| - Backend | 4 tasks (2 vCPU, 8GB each) | $464 | ₱26,216 |
| - Frontend | 2 tasks (1 vCPU, 2GB each) | $58 | ₱3,277 |
| - Workers (Default) | 2 tasks (2 vCPU, 4GB each) | $116 | ₱6,554 |
| - Workers (Long) | 2 tasks (2 vCPU, 4GB each) | $116 | ₱6,554 |
| - Workers (Short) | 2 tasks (1 vCPU, 2GB each) | $58 | ₱3,277 |
| - Scheduler | 1 task (1 vCPU, 2GB) | $29 | ₱1,639 |
| - WebSocket | 2 tasks (1 vCPU, 2GB each) | $58 | ₱3,277 |
| **Managed Services** | | | |
| RDS MySQL | db.r5.xlarge (Multi-AZ) | $460 | ₱25,990 |
| RDS Read Replica | db.r5.large | $115 | ₱6,498 |
| MemoryDB Redis | 2 × db.r6g.large | $180 | ₱10,170 |
| ALB | 2 load balancers (HA) | $44 | ₱2,486 |
| EFS | 250GB | $75 | ₱4,238 |
| S3 | 1TB | $23 | ₱1,300 |
| NAT Gateway | 3 gateways (Multi-AZ) | $135 | ₱7,628 |
| CloudFront CDN | Standard distribution | $30 | ₱1,695 |
| ECR | Container images (25GB) | $3 | ₱170 |
| CloudWatch | Detailed monitoring | $60 | ₱3,390 |
| Container Insights | ECS monitoring | $30 | ₱1,695 |
| X-Ray | Distributed tracing | $15 | ₱848 |
| Secrets Manager | 25 secrets | $10 | ₱565 |
| Systems Manager | Parameter Store | $5 | ₱283 |
| AWS WAF | Web application firewall | $25 | ₱1,413 |
| AWS Shield Standard | DDoS protection | $0 | ₱0 |
| Data Transfer | ~1TB | $90 | ₱5,085 |
| **Subtotal** | | **$2,190** | **₱123,735** |

### Disaster Recovery Site (Hot Standby)
| Component | Specification | Monthly Cost (USD) | Monthly Cost (PHP) |
|-----------|--------------|-------------------|-------------------|
| **ECS Fargate Tasks** | | | |
| - Backend | 4 tasks (2 vCPU, 8GB each) | $464 | ₱26,216 |
| - Frontend | 2 tasks (1 vCPU, 2GB each) | $58 | ₱3,277 |
| - Workers (All types) | 6 tasks (mixed sizing) | $290 | ₱16,385 |
| - Scheduler | 1 task (1 vCPU, 2GB) | $29 | ₱1,639 |
| - WebSocket | 2 tasks (1 vCPU, 2GB each) | $58 | ₱3,277 |
| **Managed Services** | | | |
| RDS MySQL | db.r5.xlarge (Multi-AZ, Read Replica) | $460 | ₱25,990 |
| MemoryDB Redis | 2 × db.r6g.large | $180 | ₱10,170 |
| ALB | 2 load balancers | $44 | ₱2,486 |
| EFS | 250GB (Cross-region replication) | $150 | ₱8,475 |
| S3 | 1TB (Cross-region replication) | $46 | ₱2,599 |
| NAT Gateway | 3 gateways | $135 | ₱7,628 |
| CloudFront CDN | Shared with production | $0 | ₱0 |
| ECR | Cross-region replication | $5 | ₱283 |
| Cross-Region Data Transfer | Database & storage sync | $250 | ₱14,125 |
| Route 53 Health Checks | Failover routing | $30 | ₱1,695 |
| CloudWatch | Cross-region monitoring | $25 | ₱1,413 |
| **Subtotal** | | **$2,224** | **₱125,658** |

### Disaster Recovery Site (Warm Standby)
| Component | Specification | Monthly Cost (USD) | Monthly Cost (PHP) |
|-----------|--------------|-------------------|-------------------|
| **ECS Fargate Tasks** | | | |
| - Backend | 1 task (1 vCPU, 2GB) | $29 | ₱1,639 |
| - Frontend | 1 task (0.5 vCPU, 1GB) | $15 | ₱848 |
| - Workers | 1 task (1 vCPU, 2GB) | $29 | ₱1,639 |
| - Scheduler | 1 task (0.5 vCPU, 1GB) | $15 | ₱848 |
| **Managed Services** | | | |
| RDS MySQL | db.t3.medium (Single-AZ, Read Replica) | $102 | ₱5,763 |
| MemoryDB Redis | 1 × db.t4g.small | $25 | ₱1,413 |
| ALB | 1 load balancer | $22 | ₱1,243 |
| EFS | 250GB (Daily sync) | $75 | ₱4,238 |
| S3 | 1TB backup storage | $23 | ₱1,300 |
| NAT Gateway | 1 gateway | $45 | ₱2,543 |
| ECR | Minimal replication | $1 | ₱57 |
| Lambda | Scaling automation | $10 | ₱565 |
| EventBridge | Scheduled tasks | $2 | ₱113 |
| AWS Backup | Automated backups | $15 | ₱848 |
| **Subtotal** | | **$408** | **₱23,052** |

### **Total Monthly Infrastructure Costs**
| Environment | Monthly Cost (USD) | Monthly Cost (PHP) |
|------------|-------------------|-------------------|
| Development | $204 | ₱11,526 |
| SIT | $348 | ₱19,664 |
| UAT | $741 | ₱41,867 |
| Production | $2,190 | ₱123,735 |
| DR (Hot) | $2,224 | ₱125,658 |
| DR (Warm) | $408 | ₱23,052 |
| **TOTAL (Hot DR)** | **$5,707** | **₱322,450** |
| **TOTAL (Warm DR)** | **$3,891** | **₱219,842** |

---

## 2. Operational Costs (Annual)

### Personnel Costs
| Role | FTE | Annual Cost (USD) | Annual Cost (PHP) |
|------|-----|-------------------|-------------------|
| Cloud Architect (Part-time) | 0.25 | $37,500 | ₱2,118,750 |
| DevOps Engineers | 1.5 | $180,000 | ₱10,170,000 |
| Database Administrator (Part-time) | 0.25 | $27,500 | ₱1,553,750 |
| Security Engineer (Part-time) | 0.25 | $32,500 | ₱1,836,250 |
| Support Team (Business hours) | 1 | $60,000 | ₱3,390,000 |
| **Subtotal** | 3.25 | **$337,500** | **₱19,068,750** |

### AWS Support & Services
| Service | Annual Cost (USD) | Annual Cost (PHP) |
|---------|-------------------|-------------------|
| AWS Developer Support (3% of spend) | $2,051 | ₱115,882 |
| Third-party Monitoring (Basic) | $6,000 | ₱339,000 |
| Security Audit (Bi-annual) | $10,000 | ₱565,000 |
| Compliance Review | $5,000 | ₱282,500 |
| **Subtotal** | **$23,051** | **₱1,302,382** |

### Training & Certification
| Item | Annual Cost (USD) | Annual Cost (PHP) |
|------|-------------------|-------------------|
| AWS Training Programs | $5,000 | ₱282,500 |
| ECS/Fargate Training | $2,500 | ₱141,250 |
| Certification Exams | $2,500 | ₱141,250 |
| **Subtotal** | **$10,000** | **₱565,000** |

---

## 3. Software Licensing Costs (Annual)

| Software | Annual Cost (USD) | Annual Cost (PHP) |
|----------|-------------------|-------------------|
| ERPNext Community Support | $15,000 | ₱847,500 |
| Container Security (Basic) | $6,000 | ₱339,000 |
| APM Tools (Basic Plan) | $7,500 | ₱423,750 |
| Log Management | $5,000 | ₱282,500 |
| CI/CD Tools | $4,000 | ₱226,000 |
| **Subtotal** | **$37,500** | **₱2,118,750** |

---

## 4. Migration & Implementation Costs (One-time, Year 1)

| Activity | Cost (USD) | Cost (PHP) |
|----------|------------|------------|
| Initial Assessment & Planning | $10,000 | ₱565,000 |
| Containerization of ERPNext | $15,000 | ₱847,500 |
| ECS Architecture Design | $12,500 | ₱706,250 |
| Data Migration Services | $20,000 | ₱1,130,000 |
| Testing & Validation | $12,500 | ₱706,250 |
| Training & Knowledge Transfer | $10,000 | ₱565,000 |
| Go-Live Support (2 months) | $15,000 | ₱847,500 |
| **Total** | **$95,000** | **₱5,367,500** |

---

## 5. Cost Optimization with Reserved Instances & Savings Plans (3-Year Term)

### Fargate Compute Savings Plans
| Component | Standard Cost/Year | With Savings Plan | Savings/Year | Savings (PHP) |
|-----------|-------------------|-------------------|--------------|---------------|
| Production Fargate | $10,788 | $7,551 | $3,237 | ₱182,891 |
| UAT Fargate | $3,480 | $2,436 | $1,044 | ₱58,986 |
| **Total Annual Savings** | | | **$4,281** | **₱241,877** |

### RDS Reserved Instances
| Environment | Standard Cost/Year | RI Cost/Year | Savings/Year | Savings (PHP) |
|------------|-------------------|--------------|--------------|---------------|
| Production | $6,900 | $4,140 | $2,760 | ₱155,940 |
| UAT | $1,380 | $966 | $414 | ₱23,391 |
| DR (Hot) | $5,520 | $3,312 | $2,208 | ₱124,752 |
| **Total Annual Savings** | | | **$5,382** | **₱304,083** |

### Spot Instances for Non-Production
| Environment | Standard Cost/Year | Spot Cost/Year | Savings/Year |
|------------|-------------------|----------------|--------------|
| Development | $960 | $288 | $672 |
| SIT | $1,920 | $576 | $1,344 |
| **Total Annual Savings** | | | **$2,016** |

---

## 6. Five-Year Total Cost of Ownership Summary

### Scenario 1: With Hot DR

### Year 1 (with Migration)
| Category | Cost (USD) | Cost (PHP) |
|----------|------------|------------|
| Infrastructure (12 months) | $68,484 | ₱3,869,346 |
| Reserved Instances (prepaid) | $27,000 | ₱1,525,500 |
| Operations | $370,551 | ₱20,936,132 |
| Software Licensing | $37,500 | ₱2,118,750 |
| Migration (one-time) | $95,000 | ₱5,367,500 |
| **Year 1 Total** | **$598,535** | **₱33,817,228** |

### Years 2-5 (Annual)
| Category | Cost (USD) | Cost (PHP) |
|----------|------------|------------|
| Infrastructure (with RI savings) | $58,821 | ₱3,323,387 |
| Operations | $370,551 | ₱20,936,132 |
| Software Licensing | $37,500 | ₱2,118,750 |
| **Annual Total (Years 2-5)** | **$466,872** | **₱26,378,269** |

### 5-Year Total with Hot DR
| Period | Cost (USD) | Cost (PHP) |
|--------|------------|------------|
| Year 1 | $598,535 | ₱33,817,228 |
| Year 2 | $466,872 | ₱26,378,269 |
| Year 3 | $466,872 | ₱26,378,269 |
| Year 4 (RI renewal) | $493,872 | ₱27,903,769 |
| Year 5 | $466,872 | ₱26,378,269 |
| **5-Year Total** | **$2,493,023** | **₱140,855,804** |
| **Average Annual Cost** | **$498,605** | **₱28,171,161** |
| **Cost Per User Per Month** | **$41.55** | **₱2,348** |

### Scenario 2: With Warm DR

### Year 1 (with Migration)
| Category | Cost (USD) | Cost (PHP) |
|----------|------------|------------|
| Infrastructure (12 months) | $46,692 | ₱2,638,086 |
| Reserved Instances (prepaid) | $21,000 | ₱1,186,500 |
| Operations | $370,551 | ₱20,936,132 |
| Software Licensing | $37,500 | ₱2,118,750 |
| Migration (one-time) | $95,000 | ₱5,367,500 |
| **Year 1 Total** | **$570,743** | **₱32,246,968** |

### Years 2-5 (Annual)
| Category | Cost (USD) | Cost (PHP) |
|----------|------------|------------|
| Infrastructure (with RI savings) | $39,708 | ₱2,243,502 |
| Operations | $370,551 | ₱20,936,132 |
| Software Licensing | $37,500 | ₱2,118,750 |
| **Annual Total (Years 2-5)** | **$447,759** | **₱25,298,384** |

### 5-Year Total with Warm DR
| Period | Cost (USD) | Cost (PHP) |
|--------|------------|------------|
| Year 1 | $570,743 | ₱32,246,968 |
| Year 2 | $447,759 | ₱25,298,384 |
| Year 3 | $447,759 | ₱25,298,384 |
| Year 4 (RI renewal) | $468,759 | ₱26,484,884 |
| Year 5 | $447,759 | ₱25,298,384 |
| **5-Year Total** | **$2,382,779** | **₱134,627,004** |
| **Average Annual Cost** | **$476,556** | **₱26,925,401** |
| **Cost Per User Per Month** | **$39.71** | **₱2,244** |

---

## 7. Five-Year TCO with Full Optimization

### Applied Optimizations
1. **Fargate Spot** for Dev/SIT: -$2,016/year
2. **Compute Savings Plans**: -$4,281/year  
3. **Reserved Instances** for RDS: -$5,382/year
4. **Auto-scaling** (30% reduction off-peak): -$7,200/year
5. **S3 Intelligent Tiering**: -$1,200/year
6. **Scheduled scaling** for non-prod: -$3,600/year

### Total Annual Optimization Savings: $23,679

### Optimized 5-Year TCO
| Scenario | Standard TCO | Optimized TCO | Total Savings |
|----------|--------------|---------------|---------------|
| With Hot DR | $2,493,023 | $2,374,628 | $118,395 |
| With Warm DR | $2,382,779 | $2,264,384 | $118,395 |

**Optimized Cost Per User Per Month**:
- Hot DR: $39.58 (₱2,236)
- Warm DR: $37.74 (₱2,132)

---

## 8. Cost Breakdown by Category (5-Year)

### With Warm DR (Recommended)
| Category | 5-Year Total (USD) | 5-Year Total (PHP) | Percentage |
|----------|-------------------|-------------------|------------|
| Infrastructure | $234,360 | ₱13,241,340 | 9.8% |
| ECS Fargate Compute | $420,000 | ₱23,730,000 | 17.6% |
| Managed Services (RDS/Redis) | $360,000 | ₱20,340,000 | 15.1% |
| Personnel | $1,687,500 | ₱95,343,750 | 70.8% |
| AWS Support | $115,255 | ₱6,511,908 | 4.8% |
| Software Licensing | $187,500 | ₱10,593,750 | 7.9% |
| Migration | $95,000 | ₱5,367,500 | 4.0% |
| Training | $50,000 | ₱2,825,000 | 2.1% |
| **Total** | **$2,382,779** | **₱134,627,004** | 100% |

---

## 9. ROI Considerations

### Cost Savings vs On-Premise
| Factor | Annual Savings | 5-Year Savings |
|--------|---------------|----------------|
| Hardware refresh avoided | $80,000 | $400,000 |
| Data center costs | $60,000 | $300,000 |
| Power & cooling | $25,000 | $125,000 |
| Reduced IT staff (2 FTE) | $120,000 | $600,000 |
| Reduced downtime (99.99% SLA) | $50,000 | $250,000 |
| **Total Savings** | **$335,000** | **$1,675,000** |

### Business Benefits
- **Scalability**: Handle peak loads without infrastructure investment
- **Agility**: Deploy new features 75% faster
- **Reliability**: 99.99% uptime SLA with automatic failover
- **Security**: Enterprise-grade security with compliance certifications
- **Global Reach**: Easy expansion to new regions

### Break-Even Analysis
- **Investment**: $570,743 (Year 1 with Warm DR)
- **Annual Savings**: $335,000
- **Break-even Point**: 1.7 years
- **5-Year Net Benefit**: $1,104,257

---

## 10. Recommendations

### Cost Optimization Strategies
1. **Reserved Instances**: Commit to 3-year terms for 40% savings
2. **Fargate Spot**: Use for development/testing (70% savings)
3. **Auto-scaling**: Right-size resources based on actual usage
4. **S3 Intelligent Tiering**: Automatic cost optimization for storage
5. **Scheduled Scaling**: Reduce non-production resources after hours

### Phased Implementation Approach
1. **Phase 1** (Month 1): Foundation & containerization
2. **Phase 2** (Month 2): Deploy Dev/SIT environments
3. **Phase 3** (Month 3): Deploy UAT environment
4. **Phase 4** (Month 4): Production deployment
5. **Phase 5** (Month 5): DR implementation & optimization

### Risk Mitigation
- Maintain on-premise backup for first 3 months
- Implement comprehensive monitoring and alerting
- Regular disaster recovery drills (quarterly)
- Multi-region backup strategy
- Business hours support with escalation procedures

### Growth Considerations
- Architecture scales linearly to 3,000 users without changes
- At 2,000+ users, consider dedicated support team
- At 3,000+ users, evaluate multi-region active-active deployment
- Cost per user decreases with scale (economies of scale)

### Key Success Factors
1. **Containerization expertise**: Invest in Docker/ECS training early
2. **Monitoring from day 1**: Implement CloudWatch and Container Insights
3. **Automation first**: Automate deployments, scaling, and backups
4. **Cost reviews**: Monthly cost optimization reviews
5. **Security posture**: Regular security audits and compliance checks

---

## 11. Comparison with Alternative Approaches

### ECS Fargate vs Other Options
| Platform | 5-Year TCO | Operational Complexity | Best For |
|----------|------------|------------------------|----------|
| **ECS Fargate** | $2,382,779 | Low | Organizations wanting serverless simplicity |
| EKS | $2,650,000 | Medium | Teams with Kubernetes expertise |
| EC2 Self-Managed | $2,100,000 | High | Organizations with strong ops teams |
| On-Premise | $3,500,000 | Very High | Data sovereignty requirements |

### Why ECS Fargate for 1,000 Users
1. **No infrastructure management**: Zero EC2 instances to patch/maintain
2. **Automatic scaling**: Scales in seconds, not minutes
3. **Pay-per-use**: Only pay for actual compute used
4. **Lower operational overhead**: 3.25 FTE vs 5+ for other solutions
5. **Faster time-to-market**: Deploy in weeks, not months

---

## Appendix: Detailed Assumptions

### Technical Assumptions
- 1,000 total users with 250-400 concurrent users
- Average 30 transactions per user per day
- 250GB initial data with 25% annual growth
- 99.9% uptime requirement for production
- Peak usage 2x average during month-end

### Financial Assumptions
- USD to PHP exchange rate: 56.50
- Annual inflation: 3% (not included in calculations)
- AWS price stability assumed
- Personnel cost increases: 5% annually (not included)
- No major architectural changes over 5 years

### ECS Fargate Specific Assumptions
- Task startup time: 30-60 seconds
- Container image size: <500MB per service
- Memory/CPU ratio: 1:2 minimum (1 vCPU per 2GB RAM)
- Auto-scaling response time: <1 minute
- Spot instance availability: 95% for non-production

### Compliance Requirements
- PCI DSS compliance for payment processing
- SOC 2 Type II certification
- ISO 27001 compliance
- Quarterly security audits
- Data residency in US regions only

---

**Note**: Prices are estimates based on current AWS pricing (January 2025) and may vary based on actual usage, negotiated discounts, and AWS price changes. Consider engaging AWS sales for additional discounts on annual commitments over $100K.

**Final Recommendation**: For a 1,000-user organization, ECS Fargate with Warm DR provides the optimal balance of cost ($39.71/user/month), operational simplicity (3.25 FTE), and reliability (99.9% SLA), with a 5-year TCO of $2.38M and ROI break-even at 1.7 years.