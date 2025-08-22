# ERPNext API Endpoints Documentation

Generated on: 2025-08-22 17:18:19

This document provides a comprehensive list of all available API endpoints in ERPNext.

## Authentication

All API calls require authentication. First, login to get a session:

```bash
curl -c cookies.txt -X POST \
  -H "Content-Type: application/json" \
  -d '{"usr":"Administrator","pwd":"your_password"}' \
  http://localhost:8080/api/method/login
```

## API Endpoint Pattern

All DocTypes follow the same RESTful pattern:

- **List/Search**: `GET /api/resource/{DocType}`
- **Get Single**: `GET /api/resource/{DocType}/{name}`
- **Create**: `POST /api/resource/{DocType}`
- **Update**: `PUT /api/resource/{DocType}/{name}`
- **Delete**: `DELETE /api/resource/{DocType}/{name}`

## Table of Contents

- [Accounts](#accounts)
- [Assets](#assets)
- [Automation](#automation)
- [Bulk Transaction](#bulk-transaction)
- [Buying](#buying)
- [CRM](#crm)
- [Communication](#communication)
- [Contacts](#contacts)
- [Core](#core)
- [Custom](#custom)
- [Desk](#desk)
- [E-commerce](#e-commerce)
- [ERPNext Integrations](#erpnext-integrations)
- [Email](#email)
- [Event Streaming](#event-streaming)
- [Geo](#geo)
- [Integrations](#integrations)
- [Loan Management](#loan-management)
- [Maintenance](#maintenance)
- [Manufacturing](#manufacturing)
- [Payment Gateways](#payment-gateways)
- [Payments](#payments)
- [Portal](#portal)
- [Printing](#printing)
- [Projects](#projects)
- [Quality Management](#quality-management)
- [Regional](#regional)
- [Selling](#selling)
- [Setup](#setup)
- [Social](#social)
- [Stock](#stock)
- [Subcontracting](#subcontracting)
- [Support](#support)
- [Telephony](#telephony)
- [Utilities](#utilities)
- [Website](#website)
- [Workflow](#workflow)

## Available DocTypes by Module

### Accounts

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Account | Standard | 1000 - Application of Funds (Assets) ... | `/api/resource/Account` |
| Accounting Dimension | Standard | (No records) | `/api/resource/Accounting%20Dimension` |
| Accounting Dimension Detail | Child Table | (Child of parent doc) | `/api/resource/Accounting%20Dimension%20Detail` |
| Accounting Dimension Filter | Standard | (No records) | `/api/resource/Accounting%20Dimension%20Filter` |
| Accounting Period | Standard | (No records) | `/api/resource/Accounting%20Period` |
| Accounts Settings | Single | Accounts Settings | `GET /api/resource/Accounts%20Settings/Accounts%20Settings` |
| Advance Tax | Child Table | (Child of parent doc) | `/api/resource/Advance%20Tax` |
| Advance Taxes and Charges | Child Table | (Child of parent doc) | `/api/resource/Advance%20Taxes%20and%20Charges` |
| Allowed Dimension | Child Table | (Child of parent doc) | `/api/resource/Allowed%20Dimension` |
| Allowed To Transact With | Child Table | (Child of parent doc) | `/api/resource/Allowed%20To%20Transact%20With` |
| Applicable On Account | Child Table | (Child of parent doc) | `/api/resource/Applicable%20On%20Account` |
| Bank | Standard | (No records) | `/api/resource/Bank` |
| Bank Account | Standard | (No records) | `/api/resource/Bank%20Account` |
| Bank Account Subtype | Standard | (No records) | `/api/resource/Bank%20Account%20Subtype` |
| Bank Account Type | Standard | (No records) | `/api/resource/Bank%20Account%20Type` |
| Bank Clearance | Single | Bank Clearance | `GET /api/resource/Bank%20Clearance/Bank%20Clearance` |
| Bank Clearance Detail | Child Table | (Child of parent doc) | `/api/resource/Bank%20Clearance%20Detail` |
| Bank Guarantee | Submittable | (No records) | `/api/resource/Bank%20Guarantee` |
| Bank Reconciliation Tool | Single | Bank Reconciliation Tool | `GET /api/resource/Bank%20Reconciliation%20Tool/Bank%20Reconciliation%20Tool` |
| Bank Statement Import | Standard | (No records) | `/api/resource/Bank%20Statement%20Import` |
| Bank Transaction | Submittable | (No records) | `/api/resource/Bank%20Transaction` |
| Bank Transaction Mapping | Child Table | (Child of parent doc) | `/api/resource/Bank%20Transaction%20Mapping` |
| Bank Transaction Payments | Child Table | (Child of parent doc) | `/api/resource/Bank%20Transaction%20Payments` |
| Budget | Submittable | (No records) | `/api/resource/Budget` |
| Budget Account | Child Table | (Child of parent doc) | `/api/resource/Budget%20Account` |
| Campaign Item | Child Table | (Child of parent doc) | `/api/resource/Campaign%20Item` |
| Cash Flow Mapper | Standard | Operating Activities, Investing Activ... | `/api/resource/Cash%20Flow%20Mapper` |
| Cash Flow Mapping | Standard | (No records) | `/api/resource/Cash%20Flow%20Mapping` |
| Cash Flow Mapping Accounts | Child Table | (Child of parent doc) | `/api/resource/Cash%20Flow%20Mapping%20Accounts` |
| Cash Flow Mapping Template | Standard | (No records) | `/api/resource/Cash%20Flow%20Mapping%20Template` |
| Cash Flow Mapping Template Details | Child Table | (Child of parent doc) | `/api/resource/Cash%20Flow%20Mapping%20Template%20Details` |
| Cashier Closing | Submittable | (No records) | `/api/resource/Cashier%20Closing` |
| Cashier Closing Payments | Child Table | (Child of parent doc) | `/api/resource/Cashier%20Closing%20Payments` |
| Chart of Accounts Importer | Single | Chart of Accounts Importer | `GET /api/resource/Chart%20of%20Accounts%20Importer/Chart%20of%20Accounts%20Importer` |
| Cheque Print Template | Standard | (No records) | `/api/resource/Cheque%20Print%20Template` |
| Closed Document | Child Table | (Child of parent doc) | `/api/resource/Closed%20Document` |
| Cost Center | Standard | 98LABS - 98LABS, Main - 98LABS | `/api/resource/Cost%20Center` |
| Cost Center Allocation | Submittable | (No records) | `/api/resource/Cost%20Center%20Allocation` |
| Cost Center Allocation Percentage | Child Table | (Child of parent doc) | `/api/resource/Cost%20Center%20Allocation%20Percentage` |
| Coupon Code | Standard | (No records) | `/api/resource/Coupon%20Code` |
| Currency Exchange Settings | Single | Currency Exchange Settings | `GET /api/resource/Currency%20Exchange%20Settings/Currency%20Exchange%20Settings` |
| Currency Exchange Settings Details | Child Table | (Child of parent doc) | `/api/resource/Currency%20Exchange%20Settings%20Details` |
| Currency Exchange Settings Result | Child Table | (Child of parent doc) | `/api/resource/Currency%20Exchange%20Settings%20Result` |
| Customer Group Item | Child Table | (Child of parent doc) | `/api/resource/Customer%20Group%20Item` |
| Customer Item | Child Table | (Child of parent doc) | `/api/resource/Customer%20Item` |
| Discounted Invoice | Child Table | (Child of parent doc) | `/api/resource/Discounted%20Invoice` |
| Dunning | Submittable | (No records) | `/api/resource/Dunning` |
| Dunning Letter Text | Child Table | (Child of parent doc) | `/api/resource/Dunning%20Letter%20Text` |
| Dunning Type | Standard | (No records) | `/api/resource/Dunning%20Type` |
| Exchange Rate Revaluation | Submittable | (No records) | `/api/resource/Exchange%20Rate%20Revaluation` |
| Exchange Rate Revaluation Account | Child Table | (Child of parent doc) | `/api/resource/Exchange%20Rate%20Revaluation%20Account` |
| Finance Book | Standard | (No records) | `/api/resource/Finance%20Book` |
| Fiscal Year | Standard | 2025 | `/api/resource/Fiscal%20Year` |
| Fiscal Year Company | Child Table | (Child of parent doc) | `/api/resource/Fiscal%20Year%20Company` |
| GL Entry | Standard | (No records) | `/api/resource/GL%20Entry` |
| Invoice Discounting | Submittable | (No records) | `/api/resource/Invoice%20Discounting` |
| Item Tax Template | Standard | Philippines Tax - 98LABS | `/api/resource/Item%20Tax%20Template` |
| Item Tax Template Detail | Child Table | (Child of parent doc) | `/api/resource/Item%20Tax%20Template%20Detail` |
| Journal Entry | Submittable | (No records) | `/api/resource/Journal%20Entry` |
| Journal Entry Account | Child Table | (Child of parent doc) | `/api/resource/Journal%20Entry%20Account` |
| Journal Entry Template | Standard | (No records) | `/api/resource/Journal%20Entry%20Template` |
| Journal Entry Template Account | Child Table | (Child of parent doc) | `/api/resource/Journal%20Entry%20Template%20Account` |
| Ledger Merge | Standard | (No records) | `/api/resource/Ledger%20Merge` |
| Ledger Merge Accounts | Child Table | (Child of parent doc) | `/api/resource/Ledger%20Merge%20Accounts` |
| Loyalty Point Entry | Standard | (No records) | `/api/resource/Loyalty%20Point%20Entry` |
| Loyalty Point Entry Redemption | Child Table | (Child of parent doc) | `/api/resource/Loyalty%20Point%20Entry%20Redemption` |
| Loyalty Program | Standard | (No records) | `/api/resource/Loyalty%20Program` |
| Loyalty Program Collection | Child Table | (Child of parent doc) | `/api/resource/Loyalty%20Program%20Collection` |
| Mode of Payment | Standard | Cheque, Credit Card | `/api/resource/Mode%20of%20Payment` |
| Mode of Payment Account | Child Table | (Child of parent doc) | `/api/resource/Mode%20of%20Payment%20Account` |
| Monthly Distribution | Standard | (No records) | `/api/resource/Monthly%20Distribution` |
| Monthly Distribution Percentage | Child Table | (Child of parent doc) | `/api/resource/Monthly%20Distribution%20Percentage` |
| Opening Invoice Creation Tool | Single | Opening Invoice Creation Tool | `GET /api/resource/Opening%20Invoice%20Creation%20Tool/Opening%20Invoice%20Creation%20Tool` |
| Opening Invoice Creation Tool Item | Child Table | (Child of parent doc) | `/api/resource/Opening%20Invoice%20Creation%20Tool%20Item` |
| POS Closing Entry | Submittable | (No records) | `/api/resource/POS%20Closing%20Entry` |
| POS Closing Entry Detail | Child Table | (Child of parent doc) | `/api/resource/POS%20Closing%20Entry%20Detail` |
| POS Closing Entry Taxes | Child Table | (Child of parent doc) | `/api/resource/POS%20Closing%20Entry%20Taxes` |
| POS Customer Group | Child Table | (Child of parent doc) | `/api/resource/POS%20Customer%20Group` |
| POS Field | Child Table | (Child of parent doc) | `/api/resource/POS%20Field` |
| POS Invoice | Submittable | (No records) | `/api/resource/POS%20Invoice` |
| POS Invoice Item | Child Table | (Child of parent doc) | `/api/resource/POS%20Invoice%20Item` |
| POS Invoice Merge Log | Submittable | (No records) | `/api/resource/POS%20Invoice%20Merge%20Log` |
| POS Invoice Reference | Child Table | (Child of parent doc) | `/api/resource/POS%20Invoice%20Reference` |
| POS Item Group | Child Table | (Child of parent doc) | `/api/resource/POS%20Item%20Group` |
| POS Opening Entry | Submittable | (No records) | `/api/resource/POS%20Opening%20Entry` |
| POS Opening Entry Detail | Child Table | (Child of parent doc) | `/api/resource/POS%20Opening%20Entry%20Detail` |
| POS Payment Method | Child Table | (Child of parent doc) | `/api/resource/POS%20Payment%20Method` |
| POS Profile | Standard | (No records) | `/api/resource/POS%20Profile` |
| POS Profile User | Child Table | (Child of parent doc) | `/api/resource/POS%20Profile%20User` |
| POS Search Fields | Child Table | (Child of parent doc) | `/api/resource/POS%20Search%20Fields` |
| POS Settings | Single | POS Settings | `GET /api/resource/POS%20Settings/POS%20Settings` |
| PSOA Cost Center | Child Table | (Child of parent doc) | `/api/resource/PSOA%20Cost%20Center` |
| PSOA Project | Child Table | (Child of parent doc) | `/api/resource/PSOA%20Project` |
| Party Account | Child Table | (Child of parent doc) | `/api/resource/Party%20Account` |
| Party Link | Standard | (No records) | `/api/resource/Party%20Link` |
| Payment Entry | Submittable | (No records) | `/api/resource/Payment%20Entry` |
| Payment Entry Deduction | Child Table | (Child of parent doc) | `/api/resource/Payment%20Entry%20Deduction` |
| Payment Entry Reference | Child Table | (Child of parent doc) | `/api/resource/Payment%20Entry%20Reference` |
| Payment Gateway Account | Standard | (No records) | `/api/resource/Payment%20Gateway%20Account` |
| Payment Ledger Entry | Standard | (No records) | `/api/resource/Payment%20Ledger%20Entry` |
| Payment Order | Submittable | (No records) | `/api/resource/Payment%20Order` |
| Payment Order Reference | Child Table | (Child of parent doc) | `/api/resource/Payment%20Order%20Reference` |
| Payment Reconciliation | Single | Payment Reconciliation | `GET /api/resource/Payment%20Reconciliation/Payment%20Reconciliation` |
| Payment Reconciliation Allocation | Child Table | (Child of parent doc) | `/api/resource/Payment%20Reconciliation%20Allocation` |
| Payment Reconciliation Invoice | Child Table | (Child of parent doc) | `/api/resource/Payment%20Reconciliation%20Invoice` |
| Payment Reconciliation Payment | Child Table | (Child of parent doc) | `/api/resource/Payment%20Reconciliation%20Payment` |
| Payment Request | Submittable | (No records) | `/api/resource/Payment%20Request` |
| Payment Schedule | Child Table | (Child of parent doc) | `/api/resource/Payment%20Schedule` |
| Payment Term | Standard | (No records) | `/api/resource/Payment%20Term` |
| Payment Terms Template | Standard | (No records) | `/api/resource/Payment%20Terms%20Template` |
| Payment Terms Template Detail | Child Table | (Child of parent doc) | `/api/resource/Payment%20Terms%20Template%20Detail` |
| Period Closing Voucher | Submittable | (No records) | `/api/resource/Period%20Closing%20Voucher` |
| Pricing Rule | Standard | (No records) | `/api/resource/Pricing%20Rule` |
| Pricing Rule Brand | Child Table | (Child of parent doc) | `/api/resource/Pricing%20Rule%20Brand` |
| Pricing Rule Detail | Child Table | (Child of parent doc) | `/api/resource/Pricing%20Rule%20Detail` |
| Pricing Rule Item Code | Child Table | (Child of parent doc) | `/api/resource/Pricing%20Rule%20Item%20Code` |
| Pricing Rule Item Group | Child Table | (Child of parent doc) | `/api/resource/Pricing%20Rule%20Item%20Group` |
| Process Deferred Accounting | Submittable | ACC-PDA-00001, ACC-PDA-00002 | `/api/resource/Process%20Deferred%20Accounting` |
| Process Statement Of Accounts | Standard | (No records) | `/api/resource/Process%20Statement%20Of%20Accounts` |
| Process Statement Of Accounts Customer | Child Table | (Child of parent doc) | `/api/resource/Process%20Statement%20Of%20Accounts%20Customer` |
| Promotional Scheme | Standard | (No records) | `/api/resource/Promotional%20Scheme` |
| Promotional Scheme Price Discount | Child Table | (Child of parent doc) | `/api/resource/Promotional%20Scheme%20Price%20Discount` |
| Promotional Scheme Product Discount | Child Table | (Child of parent doc) | `/api/resource/Promotional%20Scheme%20Product%20Discount` |
| Purchase Invoice | Submittable | (No records) | `/api/resource/Purchase%20Invoice` |
| Purchase Invoice Advance | Child Table | (Child of parent doc) | `/api/resource/Purchase%20Invoice%20Advance` |
| Purchase Invoice Item | Child Table | (Child of parent doc) | `/api/resource/Purchase%20Invoice%20Item` |
| Purchase Taxes and Charges | Child Table | (Child of parent doc) | `/api/resource/Purchase%20Taxes%20and%20Charges` |
| Purchase Taxes and Charges Template | Standard | Philippines Tax - 98LABS | `/api/resource/Purchase%20Taxes%20and%20Charges%20Template` |
| Repost Payment Ledger | Submittable | (No records) | `/api/resource/Repost%20Payment%20Ledger` |
| Repost Payment Ledger Items | Child Table | (Child of parent doc) | `/api/resource/Repost%20Payment%20Ledger%20Items` |
| Sales Invoice | Submittable | (No records) | `/api/resource/Sales%20Invoice` |
| Sales Invoice Advance | Child Table | (Child of parent doc) | `/api/resource/Sales%20Invoice%20Advance` |
| Sales Invoice Item | Child Table | (Child of parent doc) | `/api/resource/Sales%20Invoice%20Item` |
| Sales Invoice Payment | Child Table | (Child of parent doc) | `/api/resource/Sales%20Invoice%20Payment` |
| Sales Invoice Timesheet | Child Table | (Child of parent doc) | `/api/resource/Sales%20Invoice%20Timesheet` |
| Sales Partner Item | Child Table | (Child of parent doc) | `/api/resource/Sales%20Partner%20Item` |
| Sales Taxes and Charges | Child Table | (Child of parent doc) | `/api/resource/Sales%20Taxes%20and%20Charges` |
| Sales Taxes and Charges Template | Standard | Philippines Tax - 98LABS | `/api/resource/Sales%20Taxes%20and%20Charges%20Template` |
| Share Balance | Child Table | (Child of parent doc) | `/api/resource/Share%20Balance` |
| Share Transfer | Submittable | (No records) | `/api/resource/Share%20Transfer` |
| Share Type | Standard | Equity, Preference | `/api/resource/Share%20Type` |
| Shareholder | Standard | (No records) | `/api/resource/Shareholder` |
| Shipping Rule | Standard | (No records) | `/api/resource/Shipping%20Rule` |
| Shipping Rule Condition | Child Table | (Child of parent doc) | `/api/resource/Shipping%20Rule%20Condition` |
| Shipping Rule Country | Child Table | (Child of parent doc) | `/api/resource/Shipping%20Rule%20Country` |
| South Africa VAT Account | Child Table | (Child of parent doc) | `/api/resource/South%20Africa%20VAT%20Account` |
| Subscription | Standard | (No records) | `/api/resource/Subscription` |
| Subscription Invoice | Child Table | (Child of parent doc) | `/api/resource/Subscription%20Invoice` |
| Subscription Plan | Standard | (No records) | `/api/resource/Subscription%20Plan` |
| Subscription Plan Detail | Child Table | (Child of parent doc) | `/api/resource/Subscription%20Plan%20Detail` |
| Subscription Settings | Single | Subscription Settings | `GET /api/resource/Subscription%20Settings/Subscription%20Settings` |
| Supplier Group Item | Child Table | (Child of parent doc) | `/api/resource/Supplier%20Group%20Item` |
| Supplier Item | Child Table | (Child of parent doc) | `/api/resource/Supplier%20Item` |
| Tax Category | Standard | (No records) | `/api/resource/Tax%20Category` |
| Tax Rule | Standard | (No records) | `/api/resource/Tax%20Rule` |
| Tax Withheld Vouchers | Child Table | (Child of parent doc) | `/api/resource/Tax%20Withheld%20Vouchers` |
| Tax Withholding Account | Child Table | (Child of parent doc) | `/api/resource/Tax%20Withholding%20Account` |
| Tax Withholding Category | Standard | (No records) | `/api/resource/Tax%20Withholding%20Category` |
| Tax Withholding Rate | Child Table | (Child of parent doc) | `/api/resource/Tax%20Withholding%20Rate` |
| Territory Item | Child Table | (Child of parent doc) | `/api/resource/Territory%20Item` |

### Assets

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Asset | Submittable | (No records) | `/api/resource/Asset` |
| Asset Capitalization | Submittable | (No records) | `/api/resource/Asset%20Capitalization` |
| Asset Capitalization Asset Item | Child Table | (Child of parent doc) | `/api/resource/Asset%20Capitalization%20Asset%20Item` |
| Asset Capitalization Service Item | Child Table | (Child of parent doc) | `/api/resource/Asset%20Capitalization%20Service%20Item` |
| Asset Capitalization Stock Item | Child Table | (Child of parent doc) | `/api/resource/Asset%20Capitalization%20Stock%20Item` |
| Asset Category | Standard | (No records) | `/api/resource/Asset%20Category` |
| Asset Category Account | Child Table | (Child of parent doc) | `/api/resource/Asset%20Category%20Account` |
| Asset Finance Book | Child Table | (Child of parent doc) | `/api/resource/Asset%20Finance%20Book` |
| Asset Maintenance | Standard | (No records) | `/api/resource/Asset%20Maintenance` |
| Asset Maintenance Log | Submittable | (No records) | `/api/resource/Asset%20Maintenance%20Log` |
| Asset Maintenance Task | Child Table | (Child of parent doc) | `/api/resource/Asset%20Maintenance%20Task` |
| Asset Maintenance Team | Standard | (No records) | `/api/resource/Asset%20Maintenance%20Team` |
| Asset Movement | Submittable | (No records) | `/api/resource/Asset%20Movement` |
| Asset Movement Item | Child Table | (Child of parent doc) | `/api/resource/Asset%20Movement%20Item` |
| Asset Repair | Submittable | (No records) | `/api/resource/Asset%20Repair` |
| Asset Repair Consumed Item | Child Table | (Child of parent doc) | `/api/resource/Asset%20Repair%20Consumed%20Item` |
| Asset Value Adjustment | Submittable | (No records) | `/api/resource/Asset%20Value%20Adjustment` |
| Depreciation Schedule | Child Table | (Child of parent doc) | `/api/resource/Depreciation%20Schedule` |
| Linked Location | Child Table | (Child of parent doc) | `/api/resource/Linked%20Location` |
| Location | Standard | (No records) | `/api/resource/Location` |
| Maintenance Team Member | Child Table | (Child of parent doc) | `/api/resource/Maintenance%20Team%20Member` |

### Automation

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Assignment Rule | Standard | (No records) | `/api/resource/Assignment%20Rule` |
| Assignment Rule Day | Child Table | (Child of parent doc) | `/api/resource/Assignment%20Rule%20Day` |
| Assignment Rule User | Child Table | (Child of parent doc) | `/api/resource/Assignment%20Rule%20User` |
| Auto Repeat | Standard | (No records) | `/api/resource/Auto%20Repeat` |
| Auto Repeat Day | Child Table | (Child of parent doc) | `/api/resource/Auto%20Repeat%20Day` |
| Milestone | Standard | (No records) | `/api/resource/Milestone` |
| Milestone Tracker | Standard | (No records) | `/api/resource/Milestone%20Tracker` |

### Bulk Transaction

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Bulk Transaction Log | Standard | (No records) | `/api/resource/Bulk%20Transaction%20Log` |
| Bulk Transaction Log Detail | Child Table | (Child of parent doc) | `/api/resource/Bulk%20Transaction%20Log%20Detail` |

### Buying

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Buying Settings | Single | Buying Settings | `GET /api/resource/Buying%20Settings/Buying%20Settings` |
| Purchase Order | Submittable | (No records) | `/api/resource/Purchase%20Order` |
| Purchase Order Item | Child Table | (Child of parent doc) | `/api/resource/Purchase%20Order%20Item` |
| Purchase Order Item Supplied | Child Table | (Child of parent doc) | `/api/resource/Purchase%20Order%20Item%20Supplied` |
| Purchase Receipt Item Supplied | Child Table | (Child of parent doc) | `/api/resource/Purchase%20Receipt%20Item%20Supplied` |
| Request for Quotation | Submittable | (No records) | `/api/resource/Request%20for%20Quotation` |
| Request for Quotation Item | Child Table | (Child of parent doc) | `/api/resource/Request%20for%20Quotation%20Item` |
| Request for Quotation Supplier | Child Table | (Child of parent doc) | `/api/resource/Request%20for%20Quotation%20Supplier` |
| Supplier | Standard | (No records) | `/api/resource/Supplier` |
| Supplier Quotation | Submittable | (No records) | `/api/resource/Supplier%20Quotation` |
| Supplier Quotation Item | Child Table | (Child of parent doc) | `/api/resource/Supplier%20Quotation%20Item` |
| Supplier Scorecard | Standard | (No records) | `/api/resource/Supplier%20Scorecard` |
| Supplier Scorecard Criteria | Standard | (No records) | `/api/resource/Supplier%20Scorecard%20Criteria` |
| Supplier Scorecard Period | Submittable | (No records) | `/api/resource/Supplier%20Scorecard%20Period` |
| Supplier Scorecard Scoring Criteria | Child Table | (Child of parent doc) | `/api/resource/Supplier%20Scorecard%20Scoring%20Criteria` |
| Supplier Scorecard Scoring Standing | Child Table | (Child of parent doc) | `/api/resource/Supplier%20Scorecard%20Scoring%20Standing` |
| Supplier Scorecard Scoring Variable | Child Table | (Child of parent doc) | `/api/resource/Supplier%20Scorecard%20Scoring%20Variable` |
| Supplier Scorecard Standing | Standard | Very Poor, Poor | `/api/resource/Supplier%20Scorecard%20Standing` |
| Supplier Scorecard Variable | Standard | Total Accepted Items, Total Accepted ... | `/api/resource/Supplier%20Scorecard%20Variable` |

### CRM

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Appointment | Standard | (No records) | `/api/resource/Appointment` |
| Appointment Booking Settings | Single | Appointment Booking Settings | `GET /api/resource/Appointment%20Booking%20Settings/Appointment%20Booking%20Settings` |
| Appointment Booking Slots | Child Table | (Child of parent doc) | `/api/resource/Appointment%20Booking%20Slots` |
| Availability Of Slots | Child Table | (Child of parent doc) | `/api/resource/Availability%20Of%20Slots` |
| CRM Note | Child Table | (Child of parent doc) | `/api/resource/CRM%20Note` |
| CRM Settings | Single | CRM Settings | `GET /api/resource/CRM%20Settings/CRM%20Settings` |
| Campaign | Standard | (No records) | `/api/resource/Campaign` |
| Campaign Email Schedule | Child Table | (Child of parent doc) | `/api/resource/Campaign%20Email%20Schedule` |
| Competitor | Standard | (No records) | `/api/resource/Competitor` |
| Competitor Detail | Child Table | (Child of parent doc) | `/api/resource/Competitor%20Detail` |
| Contract | Submittable | (No records) | `/api/resource/Contract` |
| Contract Fulfilment Checklist | Child Table | (Child of parent doc) | `/api/resource/Contract%20Fulfilment%20Checklist` |
| Contract Template | Standard | (No records) | `/api/resource/Contract%20Template` |
| Contract Template Fulfilment Terms | Child Table | (Child of parent doc) | `/api/resource/Contract%20Template%20Fulfilment%20Terms` |
| Email Campaign | Standard | (No records) | `/api/resource/Email%20Campaign` |
| Lead | Standard | (No records) | `/api/resource/Lead` |
| Lead Source | Standard | Existing Customer, Reference | `/api/resource/Lead%20Source` |
| LinkedIn Settings | Single | LinkedIn Settings | `GET /api/resource/LinkedIn%20Settings/LinkedIn%20Settings` |
| Lost Reason Detail | Child Table | (Child of parent doc) | `/api/resource/Lost%20Reason%20Detail` |
| Market Segment | Standard | Lower Income, Middle Income | `/api/resource/Market%20Segment` |
| Opportunity | Standard | (No records) | `/api/resource/Opportunity` |
| Opportunity Item | Child Table | (Child of parent doc) | `/api/resource/Opportunity%20Item` |
| Opportunity Lost Reason | Standard | (No records) | `/api/resource/Opportunity%20Lost%20Reason` |
| Opportunity Lost Reason Detail | Child Table | (Child of parent doc) | `/api/resource/Opportunity%20Lost%20Reason%20Detail` |
| Opportunity Type | Standard | Sales, Support | `/api/resource/Opportunity%20Type` |
| Prospect | Standard | (No records) | `/api/resource/Prospect` |
| Prospect Lead | Child Table | (Child of parent doc) | `/api/resource/Prospect%20Lead` |
| Prospect Opportunity | Child Table | (Child of parent doc) | `/api/resource/Prospect%20Opportunity` |
| Sales Stage | Standard | Prospecting, Qualification | `/api/resource/Sales%20Stage` |
| Social Media Post | Submittable | (No records) | `/api/resource/Social%20Media%20Post` |
| Twitter Settings | Single | Twitter Settings | `GET /api/resource/Twitter%20Settings/Twitter%20Settings` |

### Communication

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Communication Medium | Standard | (No records) | `/api/resource/Communication%20Medium` |
| Communication Medium Timeslot | Child Table | (Child of parent doc) | `/api/resource/Communication%20Medium%20Timeslot` |

### Contacts

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Address | Standard | (No records) | `/api/resource/Address` |
| Address Template | Standard | Philippines, Taiwan | `/api/resource/Address%20Template` |
| Contact | Standard | Brian | `/api/resource/Contact` |
| Contact Email | Child Table | (Child of parent doc) | `/api/resource/Contact%20Email` |
| Contact Phone | Child Table | (Child of parent doc) | `/api/resource/Contact%20Phone` |
| Gender | Standard | Male, Female | `/api/resource/Gender` |
| Salutation | Standard | Mr, Ms | `/api/resource/Salutation` |

### Core

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Access Log | Standard | (No records) | `/api/resource/Access%20Log` |
| Activity Log | Standard | 1, 2 | `/api/resource/Activity%20Log` |
| Block Module | Child Table | (Child of parent doc) | `/api/resource/Block%20Module` |
| Comment | Standard | 705787f642 | `/api/resource/Comment` |
| Communication | Standard | (No records) | `/api/resource/Communication` |
| Communication Link | Child Table | (Child of parent doc) | `/api/resource/Communication%20Link` |
| Custom DocPerm | Standard | (No records) | `/api/resource/Custom%20DocPerm` |
| Custom Role | Standard | (No records) | `/api/resource/Custom%20Role` |
| Data Export | Single | Data Export | `GET /api/resource/Data%20Export/Data%20Export` |
| Data Import | Standard | (No records) | `/api/resource/Data%20Import` |
| Data Import Log | Standard | (No records) | `/api/resource/Data%20Import%20Log` |
| DefaultValue | Child Table | (Child of parent doc) | `/api/resource/DefaultValue` |
| Deleted Document | Standard | (No records) | `/api/resource/Deleted%20Document` |
| DocField | Child Table | (Child of parent doc) | `/api/resource/DocField` |
| DocPerm | Child Table | (Child of parent doc) | `/api/resource/DocPerm` |
| DocShare | Standard | 1 | `/api/resource/DocShare` |
| DocType | Standard | Account, Accounting Dimension | `/api/resource/DocType` |
| DocType Action | Child Table | (Child of parent doc) | `/api/resource/DocType%20Action` |
| DocType Link | Child Table | (Child of parent doc) | `/api/resource/DocType%20Link` |
| DocType State | Child Table | (Child of parent doc) | `/api/resource/DocType%20State` |
| Document Naming Rule | Standard | (No records) | `/api/resource/Document%20Naming%20Rule` |
| Document Naming Rule Condition | Child Table | (Child of parent doc) | `/api/resource/Document%20Naming%20Rule%20Condition` |
| Document Naming Settings | Single | Document Naming Settings | `GET /api/resource/Document%20Naming%20Settings/Document%20Naming%20Settings` |
| Document Share Key | Standard | (No records) | `/api/resource/Document%20Share%20Key` |
| Domain | Standard | Retail, Manufacturing | `/api/resource/Domain` |
| Domain Settings | Single | Domain Settings | `GET /api/resource/Domain%20Settings/Domain%20Settings` |
| Dynamic Link | Child Table | (Child of parent doc) | `/api/resource/Dynamic%20Link` |
| Error Log | Standard | 1, 2 | `/api/resource/Error%20Log` |
| Error Snapshot | Standard | (No records) | `/api/resource/Error%20Snapshot` |
| File | Standard | Home, Home/Attachments | `/api/resource/File` |
| Has Domain | Child Table | (Child of parent doc) | `/api/resource/Has%20Domain` |
| Has Role | Child Table | (Child of parent doc) | `/api/resource/Has%20Role` |
| Installed Application | Child Table | (Child of parent doc) | `/api/resource/Installed%20Application` |
| Installed Applications | Single | Installed Applications | `GET /api/resource/Installed%20Applications/Installed%20Applications` |
| Language | Standard | af, am | `/api/resource/Language` |
| Log Setting User | Child Table | (Child of parent doc) | `/api/resource/Log%20Setting%20User` |
| Log Settings | Single | Log Settings | `GET /api/resource/Log%20Settings/Log%20Settings` |
| Logs To Clear | Child Table | (Child of parent doc) | `/api/resource/Logs%20To%20Clear` |
| Module Def | Standard | Core, Website | `/api/resource/Module%20Def` |
| Module Profile | Standard | (No records) | `/api/resource/Module%20Profile` |
| Navbar Item | Child Table | (Child of parent doc) | `/api/resource/Navbar%20Item` |
| Navbar Settings | Single | Navbar Settings | `GET /api/resource/Navbar%20Settings/Navbar%20Settings` |
| Package | Standard | (No records) | `/api/resource/Package` |
| Package Import | Standard | (No records) | `/api/resource/Package%20Import` |
| Package Release | Standard | (No records) | `/api/resource/Package%20Release` |
| Page | Standard | activity, permission-manager | `/api/resource/Page` |
| Patch Log | Standard | PATCHLOG00001, PATCHLOG00002 | `/api/resource/Patch%20Log` |
| Prepared Report | Standard | (No records) | `/api/resource/Prepared%20Report` |
| RQ Job | Standard | (No records) | `/api/resource/RQ%20Job` |
| RQ Worker | Standard | (No records) | `/api/resource/RQ%20Worker` |
| Report | Standard | Maintenance Schedules, Serial No Status | `/api/resource/Report` |
| Report Column | Child Table | (Child of parent doc) | `/api/resource/Report%20Column` |
| Report Filter | Child Table | (Child of parent doc) | `/api/resource/Report%20Filter` |
| Role | Standard | Administrator, System Manager | `/api/resource/Role` |
| Role Permission for Page and Report | Single | Role Permission for Page and Report | `GET /api/resource/Role%20Permission%20for%20Page%20and%20Report/Role%20Permission%20for%20Page%20and%20Report` |
| Role Profile | Standard | (No records) | `/api/resource/Role%20Profile` |
| SMS Parameter | Child Table | (Child of parent doc) | `/api/resource/SMS%20Parameter` |
| SMS Settings | Single | SMS Settings | `GET /api/resource/SMS%20Settings/SMS%20Settings` |
| Scheduled Job Log | Standard | 2, 1 | `/api/resource/Scheduled%20Job%20Log` |
| Scheduled Job Type | Standard | oauth.delete_oauth2_data, web_page.ch... | `/api/resource/Scheduled%20Job%20Type` |
| Server Script | Standard | (No records) | `/api/resource/Server%20Script` |
| Session Default | Child Table | (Child of parent doc) | `/api/resource/Session%20Default` |
| Session Default Settings | Single | Session Default Settings | `GET /api/resource/Session%20Default%20Settings/Session%20Default%20Settings` |
| Success Action | Standard | Purchase Receipt, Purchase Invoice | `/api/resource/Success%20Action` |
| System Settings | Single | System Settings | `GET /api/resource/System%20Settings/System%20Settings` |
| Transaction Log | Standard | (No records) | `/api/resource/Transaction%20Log` |
| Translation | Standard | (No records) | `/api/resource/Translation` |
| User | Standard | Guest, Administrator | `/api/resource/User` |
| User Document Type | Child Table | (Child of parent doc) | `/api/resource/User%20Document%20Type` |
| User Email | Child Table | (Child of parent doc) | `/api/resource/User%20Email` |
| User Group | Standard | (No records) | `/api/resource/User%20Group` |
| User Group Member | Child Table | (Child of parent doc) | `/api/resource/User%20Group%20Member` |
| User Permission | Standard | 314510d954 | `/api/resource/User%20Permission` |
| User Select Document Type | Child Table | (Child of parent doc) | `/api/resource/User%20Select%20Document%20Type` |
| User Social Login | Child Table | (Child of parent doc) | `/api/resource/User%20Social%20Login` |
| User Type | Standard | System User, Website User | `/api/resource/User%20Type` |
| User Type Module | Child Table | (Child of parent doc) | `/api/resource/User%20Type%20Module` |
| Version | Standard | 1, 2 | `/api/resource/Version` |
| View Log | Standard | (No records) | `/api/resource/View%20Log` |

### Custom

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Client Script | Standard | (No records) | `/api/resource/Client%20Script` |
| Custom Field | Standard | Address-tax_category, Contact-is_bill... | `/api/resource/Custom%20Field` |
| Customize Form | Single | Customize Form | `GET /api/resource/Customize%20Form/Customize%20Form` |
| Customize Form Field | Child Table | (Child of parent doc) | `/api/resource/Customize%20Form%20Field` |
| DocType Layout | Standard | (No records) | `/api/resource/DocType%20Layout` |
| DocType Layout Field | Child Table | (Child of parent doc) | `/api/resource/DocType%20Layout%20Field` |
| Property Setter | Standard | Sales Order-due_date-print_hide, Sale... | `/api/resource/Property%20Setter` |

### Desk

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Bulk Update | Single | Bulk Update | `GET /api/resource/Bulk%20Update/Bulk%20Update` |
| Calendar View | Standard | (No records) | `/api/resource/Calendar%20View` |
| Console Log | Standard | (No records) | `/api/resource/Console%20Log` |
| Dashboard | Standard | Manufacturing, Asset | `/api/resource/Dashboard` |
| Dashboard Chart | Standard | Quality Inspection Analysis, Purchase... | `/api/resource/Dashboard%20Chart` |
| Dashboard Chart Field | Child Table | (Child of parent doc) | `/api/resource/Dashboard%20Chart%20Field` |
| Dashboard Chart Link | Child Table | (Child of parent doc) | `/api/resource/Dashboard%20Chart%20Link` |
| Dashboard Chart Source | Standard | Account Balance Timeline, Warehouse w... | `/api/resource/Dashboard%20Chart%20Source` |
| Dashboard Settings | Standard | (No records) | `/api/resource/Dashboard%20Settings` |
| Desktop Icon | Standard | (No records) | `/api/resource/Desktop%20Icon` |
| Event | Standard | (No records) | `/api/resource/Event` |
| Event Participants | Child Table | (Child of parent doc) | `/api/resource/Event%20Participants` |
| Form Tour | Standard | Purchase Invoice, Accounts Settings | `/api/resource/Form%20Tour` |
| Form Tour Step | Child Table | (Child of parent doc) | `/api/resource/Form%20Tour%20Step` |
| Global Search DocType | Child Table | (Child of parent doc) | `/api/resource/Global%20Search%20DocType` |
| Global Search Settings | Single | Global Search Settings | `GET /api/resource/Global%20Search%20Settings/Global%20Search%20Settings` |
| Kanban Board | Standard | (No records) | `/api/resource/Kanban%20Board` |
| Kanban Board Column | Child Table | (Child of parent doc) | `/api/resource/Kanban%20Board%20Column` |
| List Filter | Standard | (No records) | `/api/resource/List%20Filter` |
| List View Settings | Standard | (No records) | `/api/resource/List%20View%20Settings` |
| Module Onboarding | Standard | Website, Manufacturing | `/api/resource/Module%20Onboarding` |
| Note | Standard | (No records) | `/api/resource/Note` |
| Note Seen By | Child Table | (Child of parent doc) | `/api/resource/Note%20Seen%20By` |
| Notification Log | Standard | (No records) | `/api/resource/Notification%20Log` |
| Notification Settings | Standard | Administrator, Guest | `/api/resource/Notification%20Settings` |
| Notification Subscribed Document | Child Table | (Child of parent doc) | `/api/resource/Notification%20Subscribed%20Document` |
| Number Card | Standard | Monthly Total Work Order, Monthly Com... | `/api/resource/Number%20Card` |
| Number Card Link | Child Table | (Child of parent doc) | `/api/resource/Number%20Card%20Link` |
| Onboarding Permission | Child Table | (Child of parent doc) | `/api/resource/Onboarding%20Permission` |
| Onboarding Step | Standard | Create Blogger, Enable Website Tracking | `/api/resource/Onboarding%20Step` |
| Onboarding Step Map | Child Table | (Child of parent doc) | `/api/resource/Onboarding%20Step%20Map` |
| Route History | Standard | (No records) | `/api/resource/Route%20History` |
| System Console | Single | System Console | `GET /api/resource/System%20Console/System%20Console` |
| Tag | Standard | (No records) | `/api/resource/Tag` |
| Tag Link | Standard | (No records) | `/api/resource/Tag%20Link` |
| ToDo | Standard | (No records) | `/api/resource/ToDo` |
| Workspace | Standard | Accounting, Assets | `/api/resource/Workspace` |
| Workspace Chart | Child Table | (Child of parent doc) | `/api/resource/Workspace%20Chart` |
| Workspace Link | Child Table | (Child of parent doc) | `/api/resource/Workspace%20Link` |
| Workspace Quick List | Child Table | (Child of parent doc) | `/api/resource/Workspace%20Quick%20List` |
| Workspace Shortcut | Child Table | (Child of parent doc) | `/api/resource/Workspace%20Shortcut` |

### E-commerce

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| E Commerce Settings | Single | E Commerce Settings | `GET /api/resource/E%20Commerce%20Settings/E%20Commerce%20Settings` |
| Item Review | Standard | (No records) | `/api/resource/Item%20Review` |
| Recommended Items | Child Table | (Child of parent doc) | `/api/resource/Recommended%20Items` |
| Website Item | Standard | (No records) | `/api/resource/Website%20Item` |
| Website Item Tabbed Section | Child Table | (Child of parent doc) | `/api/resource/Website%20Item%20Tabbed%20Section` |
| Website Offer | Child Table | (Child of parent doc) | `/api/resource/Website%20Offer` |
| Wishlist | Standard | (No records) | `/api/resource/Wishlist` |
| Wishlist Item | Child Table | (Child of parent doc) | `/api/resource/Wishlist%20Item` |

### ERPNext Integrations

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Exotel Settings | Single | Exotel Settings | `GET /api/resource/Exotel%20Settings/Exotel%20Settings` |
| GoCardless Mandate | Standard | (No records) | `/api/resource/GoCardless%20Mandate` |
| GoCardless Settings | Standard | (No records) | `/api/resource/GoCardless%20Settings` |
| Mpesa Settings | Standard | (No records) | `/api/resource/Mpesa%20Settings` |
| Plaid Settings | Single | Plaid Settings | `GET /api/resource/Plaid%20Settings/Plaid%20Settings` |
| QuickBooks Migrator | Single | QuickBooks Migrator | `GET /api/resource/QuickBooks%20Migrator/QuickBooks%20Migrator` |
| Tally Migration | Standard | (No records) | `/api/resource/Tally%20Migration` |
| TaxJar Nexus | Child Table | (Child of parent doc) | `/api/resource/TaxJar%20Nexus` |
| TaxJar Settings | Single | TaxJar Settings | `GET /api/resource/TaxJar%20Settings/TaxJar%20Settings` |
| Woocommerce Settings | Single | Woocommerce Settings | `GET /api/resource/Woocommerce%20Settings/Woocommerce%20Settings` |

### Email

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Auto Email Report | Standard | (No records) | `/api/resource/Auto%20Email%20Report` |
| Document Follow | Standard | (No records) | `/api/resource/Document%20Follow` |
| Email Account | Standard | Notifications, Replies | `/api/resource/Email%20Account` |
| Email Domain | Standard | example.com | `/api/resource/Email%20Domain` |
| Email Flag Queue | Standard | (No records) | `/api/resource/Email%20Flag%20Queue` |
| Email Group | Standard | (No records) | `/api/resource/Email%20Group` |
| Email Group Member | Standard | (No records) | `/api/resource/Email%20Group%20Member` |
| Email Queue | Standard | (No records) | `/api/resource/Email%20Queue` |
| Email Queue Recipient | Child Table | (Child of parent doc) | `/api/resource/Email%20Queue%20Recipient` |
| Email Rule | Standard | (No records) | `/api/resource/Email%20Rule` |
| Email Template | Standard | Dispatch Notification | `/api/resource/Email%20Template` |
| Email Unsubscribe | Standard | 250112b61f, ac8e9adb2b | `/api/resource/Email%20Unsubscribe` |
| IMAP Folder | Child Table | (Child of parent doc) | `/api/resource/IMAP%20Folder` |
| Newsletter | Standard | (No records) | `/api/resource/Newsletter` |
| Newsletter Attachment | Child Table | (Child of parent doc) | `/api/resource/Newsletter%20Attachment` |
| Newsletter Email Group | Child Table | (Child of parent doc) | `/api/resource/Newsletter%20Email%20Group` |
| Notification | Standard | Notification for new fiscal year, Mat... | `/api/resource/Notification` |
| Notification Recipient | Child Table | (Child of parent doc) | `/api/resource/Notification%20Recipient` |
| Unhandled Email | Standard | (No records) | `/api/resource/Unhandled%20Email` |

### Event Streaming

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Document Type Field Mapping | Child Table | (Child of parent doc) | `/api/resource/Document%20Type%20Field%20Mapping` |
| Document Type Mapping | Standard | (No records) | `/api/resource/Document%20Type%20Mapping` |
| Event Consumer | Standard | (No records) | `/api/resource/Event%20Consumer` |
| Event Consumer Document Type | Child Table | (Child of parent doc) | `/api/resource/Event%20Consumer%20Document%20Type` |
| Event Producer | Standard | (No records) | `/api/resource/Event%20Producer` |
| Event Producer Document Type | Child Table | (Child of parent doc) | `/api/resource/Event%20Producer%20Document%20Type` |
| Event Producer Last Update | Standard | (No records) | `/api/resource/Event%20Producer%20Last%20Update` |
| Event Sync Log | Standard | (No records) | `/api/resource/Event%20Sync%20Log` |
| Event Update Log | Standard | (No records) | `/api/resource/Event%20Update%20Log` |
| Event Update Log Consumer | Child Table | (Child of parent doc) | `/api/resource/Event%20Update%20Log%20Consumer` |

### Geo

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Country | Standard | Afghanistan, Albania | `/api/resource/Country` |
| Currency | Standard | AFN, ALL | `/api/resource/Currency` |

### Integrations

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Connected App | Standard | (No records) | `/api/resource/Connected%20App` |
| Dropbox Settings | Single | Dropbox Settings | `GET /api/resource/Dropbox%20Settings/Dropbox%20Settings` |
| Google Calendar | Standard | (No records) | `/api/resource/Google%20Calendar` |
| Google Contacts | Standard | (No records) | `/api/resource/Google%20Contacts` |
| Google Drive | Single | Google Drive | `GET /api/resource/Google%20Drive/Google%20Drive` |
| Google Settings | Single | Google Settings | `GET /api/resource/Google%20Settings/Google%20Settings` |
| Integration Request | Standard | (No records) | `/api/resource/Integration%20Request` |
| LDAP Group Mapping | Child Table | (Child of parent doc) | `/api/resource/LDAP%20Group%20Mapping` |
| LDAP Settings | Single | LDAP Settings | `GET /api/resource/LDAP%20Settings/LDAP%20Settings` |
| OAuth Authorization Code | Standard | (No records) | `/api/resource/OAuth%20Authorization%20Code` |
| OAuth Bearer Token | Standard | (No records) | `/api/resource/OAuth%20Bearer%20Token` |
| OAuth Client | Standard | (No records) | `/api/resource/OAuth%20Client` |
| OAuth Provider Settings | Single | OAuth Provider Settings | `GET /api/resource/OAuth%20Provider%20Settings/OAuth%20Provider%20Settings` |
| OAuth Scope | Child Table | (Child of parent doc) | `/api/resource/OAuth%20Scope` |
| Query Parameters | Child Table | (Child of parent doc) | `/api/resource/Query%20Parameters` |
| S3 Backup Settings | Single | S3 Backup Settings | `GET /api/resource/S3%20Backup%20Settings/S3%20Backup%20Settings` |
| Slack Webhook URL | Standard | (No records) | `/api/resource/Slack%20Webhook%20URL` |
| Social Login Key | Standard | (No records) | `/api/resource/Social%20Login%20Key` |
| Token Cache | Standard | (No records) | `/api/resource/Token%20Cache` |
| Webhook | Standard | (No records) | `/api/resource/Webhook` |
| Webhook Data | Child Table | (Child of parent doc) | `/api/resource/Webhook%20Data` |
| Webhook Header | Child Table | (Child of parent doc) | `/api/resource/Webhook%20Header` |
| Webhook Request Log | Standard | (No records) | `/api/resource/Webhook%20Request%20Log` |

### Loan Management

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Loan | Submittable | (No records) | `/api/resource/Loan` |
| Loan Application | Submittable | (No records) | `/api/resource/Loan%20Application` |
| Loan Balance Adjustment | Submittable | (No records) | `/api/resource/Loan%20Balance%20Adjustment` |
| Loan Disbursement | Submittable | (No records) | `/api/resource/Loan%20Disbursement` |
| Loan Interest Accrual | Submittable | (No records) | `/api/resource/Loan%20Interest%20Accrual` |
| Loan Refund | Submittable | (No records) | `/api/resource/Loan%20Refund` |
| Loan Repayment | Submittable | (No records) | `/api/resource/Loan%20Repayment` |
| Loan Repayment Detail | Child Table | (Child of parent doc) | `/api/resource/Loan%20Repayment%20Detail` |
| Loan Security | Standard | (No records) | `/api/resource/Loan%20Security` |
| Loan Security Pledge | Submittable | (No records) | `/api/resource/Loan%20Security%20Pledge` |
| Loan Security Price | Standard | (No records) | `/api/resource/Loan%20Security%20Price` |
| Loan Security Shortfall | Standard | (No records) | `/api/resource/Loan%20Security%20Shortfall` |
| Loan Security Type | Standard | (No records) | `/api/resource/Loan%20Security%20Type` |
| Loan Security Unpledge | Submittable | (No records) | `/api/resource/Loan%20Security%20Unpledge` |
| Loan Type | Submittable | (No records) | `/api/resource/Loan%20Type` |
| Loan Write Off | Submittable | (No records) | `/api/resource/Loan%20Write%20Off` |
| Pledge | Child Table | (Child of parent doc) | `/api/resource/Pledge` |
| Process Loan Interest Accrual | Submittable | LM-PLA-00001 | `/api/resource/Process%20Loan%20Interest%20Accrual` |
| Process Loan Security Shortfall | Submittable | (No records) | `/api/resource/Process%20Loan%20Security%20Shortfall` |
| Proposed Pledge | Child Table | (Child of parent doc) | `/api/resource/Proposed%20Pledge` |
| Repayment Schedule | Child Table | (Child of parent doc) | `/api/resource/Repayment%20Schedule` |
| Sanctioned Loan Amount | Standard | (No records) | `/api/resource/Sanctioned%20Loan%20Amount` |
| Unpledge | Child Table | (Child of parent doc) | `/api/resource/Unpledge` |

### Maintenance

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Maintenance Schedule | Submittable | (No records) | `/api/resource/Maintenance%20Schedule` |
| Maintenance Schedule Detail | Child Table | (Child of parent doc) | `/api/resource/Maintenance%20Schedule%20Detail` |
| Maintenance Schedule Item | Child Table | (Child of parent doc) | `/api/resource/Maintenance%20Schedule%20Item` |
| Maintenance Visit | Submittable | (No records) | `/api/resource/Maintenance%20Visit` |
| Maintenance Visit Purpose | Child Table | (Child of parent doc) | `/api/resource/Maintenance%20Visit%20Purpose` |

### Manufacturing

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| BOM | Submittable | (No records) | `/api/resource/BOM` |
| BOM Explosion Item | Child Table | (Child of parent doc) | `/api/resource/BOM%20Explosion%20Item` |
| BOM Item | Child Table | (Child of parent doc) | `/api/resource/BOM%20Item` |
| BOM Operation | Child Table | (Child of parent doc) | `/api/resource/BOM%20Operation` |
| BOM Scrap Item | Child Table | (Child of parent doc) | `/api/resource/BOM%20Scrap%20Item` |
| BOM Update Batch | Child Table | (Child of parent doc) | `/api/resource/BOM%20Update%20Batch` |
| BOM Update Log | Submittable | (No records) | `/api/resource/BOM%20Update%20Log` |
| BOM Update Tool | Single | BOM Update Tool | `GET /api/resource/BOM%20Update%20Tool/BOM%20Update%20Tool` |
| BOM Website Item | Child Table | (Child of parent doc) | `/api/resource/BOM%20Website%20Item` |
| BOM Website Operation | Child Table | (Child of parent doc) | `/api/resource/BOM%20Website%20Operation` |
| Blanket Order | Submittable | (No records) | `/api/resource/Blanket%20Order` |
| Blanket Order Item | Child Table | (Child of parent doc) | `/api/resource/Blanket%20Order%20Item` |
| Downtime Entry | Standard | (No records) | `/api/resource/Downtime%20Entry` |
| Job Card | Submittable | (No records) | `/api/resource/Job%20Card` |
| Job Card Item | Child Table | (Child of parent doc) | `/api/resource/Job%20Card%20Item` |
| Job Card Operation | Child Table | (Child of parent doc) | `/api/resource/Job%20Card%20Operation` |
| Job Card Scrap Item | Child Table | (Child of parent doc) | `/api/resource/Job%20Card%20Scrap%20Item` |
| Job Card Time Log | Child Table | (Child of parent doc) | `/api/resource/Job%20Card%20Time%20Log` |
| Manufacturing Settings | Single | Manufacturing Settings | `GET /api/resource/Manufacturing%20Settings/Manufacturing%20Settings` |
| Material Request Plan Item | Child Table | (Child of parent doc) | `/api/resource/Material%20Request%20Plan%20Item` |
| Operation | Standard | (No records) | `/api/resource/Operation` |
| Production Plan | Submittable | (No records) | `/api/resource/Production%20Plan` |
| Production Plan Item | Child Table | (Child of parent doc) | `/api/resource/Production%20Plan%20Item` |
| Production Plan Item Reference | Child Table | (Child of parent doc) | `/api/resource/Production%20Plan%20Item%20Reference` |
| Production Plan Material Request | Child Table | (Child of parent doc) | `/api/resource/Production%20Plan%20Material%20Request` |
| Production Plan Material Request Warehouse | Child Table | (Child of parent doc) | `/api/resource/Production%20Plan%20Material%20Request%20Warehouse` |
| Production Plan Sales Order | Child Table | (Child of parent doc) | `/api/resource/Production%20Plan%20Sales%20Order` |
| Production Plan Sub Assembly Item | Child Table | (Child of parent doc) | `/api/resource/Production%20Plan%20Sub%20Assembly%20Item` |
| Routing | Standard | (No records) | `/api/resource/Routing` |
| Sub Operation | Child Table | (Child of parent doc) | `/api/resource/Sub%20Operation` |
| Work Order | Submittable | (No records) | `/api/resource/Work%20Order` |
| Work Order Item | Child Table | (Child of parent doc) | `/api/resource/Work%20Order%20Item` |
| Work Order Operation | Child Table | (Child of parent doc) | `/api/resource/Work%20Order%20Operation` |
| Workstation | Standard | (No records) | `/api/resource/Workstation` |
| Workstation Type | Standard | (No records) | `/api/resource/Workstation%20Type` |
| Workstation Working Hour | Child Table | (Child of parent doc) | `/api/resource/Workstation%20Working%20Hour` |

### Payment Gateways

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Braintree Settings | Standard | (No records) | `/api/resource/Braintree%20Settings` |
| PayPal Settings | Single | PayPal Settings | `GET /api/resource/PayPal%20Settings/PayPal%20Settings` |
| Paytm Settings | Single | Paytm Settings | `GET /api/resource/Paytm%20Settings/Paytm%20Settings` |
| Razorpay Settings | Single | Razorpay Settings | `GET /api/resource/Razorpay%20Settings/Razorpay%20Settings` |
| Stripe Settings | Standard | (No records) | `/api/resource/Stripe%20Settings` |

### Payments

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Payment Gateway | Standard | (No records) | `/api/resource/Payment%20Gateway` |

### Portal

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Homepage | Single | Homepage | `GET /api/resource/Homepage/Homepage` |
| Homepage Featured Product | Child Table | (Child of parent doc) | `/api/resource/Homepage%20Featured%20Product` |
| Homepage Section | Standard | (No records) | `/api/resource/Homepage%20Section` |
| Homepage Section Card | Child Table | (Child of parent doc) | `/api/resource/Homepage%20Section%20Card` |
| Website Attribute | Child Table | (Child of parent doc) | `/api/resource/Website%20Attribute` |
| Website Filter Field | Child Table | (Child of parent doc) | `/api/resource/Website%20Filter%20Field` |

### Printing

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Letter Head | Standard | (No records) | `/api/resource/Letter%20Head` |
| Network Printer Settings | Standard | (No records) | `/api/resource/Network%20Printer%20Settings` |
| Print Format | Standard | Cheque Printing Format, Payment Recei... | `/api/resource/Print%20Format` |
| Print Format Field Template | Standard | (No records) | `/api/resource/Print%20Format%20Field%20Template` |
| Print Settings | Single | Print Settings | `GET /api/resource/Print%20Settings/Print%20Settings` |
| Print Style | Standard | Classic, Monochrome | `/api/resource/Print%20Style` |

### Projects

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Activity Cost | Standard | (No records) | `/api/resource/Activity%20Cost` |
| Activity Type | Standard | Planning, Research | `/api/resource/Activity%20Type` |
| Dependent Task | Child Table | (Child of parent doc) | `/api/resource/Dependent%20Task` |
| Project | Standard | (No records) | `/api/resource/Project` |
| Project Template | Standard | (No records) | `/api/resource/Project%20Template` |
| Project Template Task | Child Table | (Child of parent doc) | `/api/resource/Project%20Template%20Task` |
| Project Type | Standard | Internal, External | `/api/resource/Project%20Type` |
| Project Update | Submittable | (No records) | `/api/resource/Project%20Update` |
| Project User | Child Table | (Child of parent doc) | `/api/resource/Project%20User` |
| Projects Settings | Single | Projects Settings | `GET /api/resource/Projects%20Settings/Projects%20Settings` |
| Task | Standard | (No records) | `/api/resource/Task` |
| Task Depends On | Child Table | (Child of parent doc) | `/api/resource/Task%20Depends%20On` |
| Task Type | Standard | (No records) | `/api/resource/Task%20Type` |
| Timesheet | Submittable | (No records) | `/api/resource/Timesheet` |
| Timesheet Detail | Child Table | (Child of parent doc) | `/api/resource/Timesheet%20Detail` |

### Quality Management

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Non Conformance | Standard | (No records) | `/api/resource/Non%20Conformance` |
| Quality Action | Standard | (No records) | `/api/resource/Quality%20Action` |
| Quality Action Resolution | Child Table | (Child of parent doc) | `/api/resource/Quality%20Action%20Resolution` |
| Quality Feedback | Standard | (No records) | `/api/resource/Quality%20Feedback` |
| Quality Feedback Parameter | Child Table | (Child of parent doc) | `/api/resource/Quality%20Feedback%20Parameter` |
| Quality Feedback Template | Standard | (No records) | `/api/resource/Quality%20Feedback%20Template` |
| Quality Feedback Template Parameter | Child Table | (Child of parent doc) | `/api/resource/Quality%20Feedback%20Template%20Parameter` |
| Quality Goal | Standard | (No records) | `/api/resource/Quality%20Goal` |
| Quality Goal Objective | Child Table | (Child of parent doc) | `/api/resource/Quality%20Goal%20Objective` |
| Quality Meeting | Standard | (No records) | `/api/resource/Quality%20Meeting` |
| Quality Meeting Agenda | Child Table | (Child of parent doc) | `/api/resource/Quality%20Meeting%20Agenda` |
| Quality Meeting Minutes | Child Table | (Child of parent doc) | `/api/resource/Quality%20Meeting%20Minutes` |
| Quality Procedure | Standard | (No records) | `/api/resource/Quality%20Procedure` |
| Quality Procedure Process | Child Table | (Child of parent doc) | `/api/resource/Quality%20Procedure%20Process` |
| Quality Review | Standard | (No records) | `/api/resource/Quality%20Review` |
| Quality Review Objective | Child Table | (Child of parent doc) | `/api/resource/Quality%20Review%20Objective` |

### Regional

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Import Supplier Invoice | Standard | (No records) | `/api/resource/Import%20Supplier%20Invoice` |
| KSA VAT Purchase Account | Child Table | (Child of parent doc) | `/api/resource/KSA%20VAT%20Purchase%20Account` |
| KSA VAT Sales Account | Child Table | (Child of parent doc) | `/api/resource/KSA%20VAT%20Sales%20Account` |
| KSA VAT Setting | Standard | (No records) | `/api/resource/KSA%20VAT%20Setting` |
| Lower Deduction Certificate | Standard | (No records) | `/api/resource/Lower%20Deduction%20Certificate` |
| Product Tax Category | Standard | (No records) | `/api/resource/Product%20Tax%20Category` |
| South Africa VAT Settings | Standard | (No records) | `/api/resource/South%20Africa%20VAT%20Settings` |
| UAE VAT Account | Child Table | (Child of parent doc) | `/api/resource/UAE%20VAT%20Account` |
| UAE VAT Settings | Standard | (No records) | `/api/resource/UAE%20VAT%20Settings` |

### Selling

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Customer | Standard | (No records) | `/api/resource/Customer` |
| Customer Credit Limit | Child Table | (Child of parent doc) | `/api/resource/Customer%20Credit%20Limit` |
| Industry Type | Standard | Accounting, Advertising | `/api/resource/Industry%20Type` |
| Installation Note | Submittable | (No records) | `/api/resource/Installation%20Note` |
| Installation Note Item | Child Table | (Child of parent doc) | `/api/resource/Installation%20Note%20Item` |
| Party Specific Item | Standard | (No records) | `/api/resource/Party%20Specific%20Item` |
| Product Bundle | Standard | (No records) | `/api/resource/Product%20Bundle` |
| Product Bundle Item | Child Table | (Child of parent doc) | `/api/resource/Product%20Bundle%20Item` |
| Quotation | Submittable | (No records) | `/api/resource/Quotation` |
| Quotation Item | Child Table | (Child of parent doc) | `/api/resource/Quotation%20Item` |
| SMS Center | Single | SMS Center | `GET /api/resource/SMS%20Center/SMS%20Center` |
| Sales Order | Submittable | (No records) | `/api/resource/Sales%20Order` |
| Sales Order Item | Child Table | (Child of parent doc) | `/api/resource/Sales%20Order%20Item` |
| Sales Partner Type | Standard | Channel Partner, Distributor | `/api/resource/Sales%20Partner%20Type` |
| Sales Team | Child Table | (Child of parent doc) | `/api/resource/Sales%20Team` |
| Selling Settings | Single | Selling Settings | `GET /api/resource/Selling%20Settings/Selling%20Settings` |

### Setup

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Authorization Control | Single | Authorization Control | `GET /api/resource/Authorization%20Control/Authorization%20Control` |
| Authorization Rule | Standard | (No records) | `/api/resource/Authorization%20Rule` |
| Branch | Standard | (No records) | `/api/resource/Branch` |
| Brand | Standard | (No records) | `/api/resource/Brand` |
| Company | Standard | 98LABS | `/api/resource/Company` |
| Currency Exchange | Standard | (No records) | `/api/resource/Currency%20Exchange` |
| Customer Group | Standard | All Customer Groups, Individual | `/api/resource/Customer%20Group` |
| Department | Standard | All Departments, Accounts | `/api/resource/Department` |
| Designation | Standard | CEO, Manager | `/api/resource/Designation` |
| Driver | Standard | (No records) | `/api/resource/Driver` |
| Driving License Category | Child Table | (Child of parent doc) | `/api/resource/Driving%20License%20Category` |
| Email Digest | Standard | Default Weekly Digest - 98LABS, Sched... | `/api/resource/Email%20Digest` |
| Email Digest Recipient | Child Table | (Child of parent doc) | `/api/resource/Email%20Digest%20Recipient` |
| Employee | Standard | (No records) | `/api/resource/Employee` |
| Employee Education | Child Table | (Child of parent doc) | `/api/resource/Employee%20Education` |
| Employee External Work History | Child Table | (Child of parent doc) | `/api/resource/Employee%20External%20Work%20History` |
| Employee Group | Standard | (No records) | `/api/resource/Employee%20Group` |
| Employee Group Table | Child Table | (Child of parent doc) | `/api/resource/Employee%20Group%20Table` |
| Employee Internal Work History | Child Table | (Child of parent doc) | `/api/resource/Employee%20Internal%20Work%20History` |
| Global Defaults | Single | Global Defaults | `GET /api/resource/Global%20Defaults/Global%20Defaults` |
| Holiday | Child Table | (Child of parent doc) | `/api/resource/Holiday` |
| Holiday List | Standard | (No records) | `/api/resource/Holiday%20List` |
| Incoterm | Standard | EXW, FCA | `/api/resource/Incoterm` |
| Item Group | Standard | All Item Groups, Products | `/api/resource/Item%20Group` |
| Party Type | Standard | Customer, Supplier | `/api/resource/Party%20Type` |
| Print Heading | Standard | Credit Note, Debit Note | `/api/resource/Print%20Heading` |
| Quotation Lost Reason | Standard | (No records) | `/api/resource/Quotation%20Lost%20Reason` |
| Quotation Lost Reason Detail | Child Table | (Child of parent doc) | `/api/resource/Quotation%20Lost%20Reason%20Detail` |
| Sales Partner | Standard | (No records) | `/api/resource/Sales%20Partner` |
| Sales Person | Standard | Sales Team | `/api/resource/Sales%20Person` |
| Supplier Group | Standard | All Supplier Groups, Services | `/api/resource/Supplier%20Group` |
| Target Detail | Child Table | (Child of parent doc) | `/api/resource/Target%20Detail` |
| Terms and Conditions | Standard | (No records) | `/api/resource/Terms%20and%20Conditions` |
| Territory | Standard | All Territories, Philippines | `/api/resource/Territory` |
| Transaction Deletion Record | Submittable | (No records) | `/api/resource/Transaction%20Deletion%20Record` |
| Transaction Deletion Record Item | Child Table | (Child of parent doc) | `/api/resource/Transaction%20Deletion%20Record%20Item` |
| UOM | Standard | Unit, Box | `/api/resource/UOM` |
| UOM Conversion Factor | Standard | MAT-UOM-CNV-00001, MAT-UOM-CNV-00002 | `/api/resource/UOM%20Conversion%20Factor` |
| Vehicle | Standard | (No records) | `/api/resource/Vehicle` |
| Website Item Group | Child Table | (Child of parent doc) | `/api/resource/Website%20Item%20Group` |

### Social

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Energy Point Log | Standard | (No records) | `/api/resource/Energy%20Point%20Log` |
| Energy Point Rule | Standard | On Item Creation, On Customer Creation | `/api/resource/Energy%20Point%20Rule` |
| Energy Point Settings | Single | Energy Point Settings | `GET /api/resource/Energy%20Point%20Settings/Energy%20Point%20Settings` |
| Review Level | Child Table | (Child of parent doc) | `/api/resource/Review%20Level` |

### Stock

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Batch | Standard | (No records) | `/api/resource/Batch` |
| Bin | Standard | (No records) | `/api/resource/Bin` |
| Customs Tariff Number | Standard | (No records) | `/api/resource/Customs%20Tariff%20Number` |
| Delivery Note | Submittable | (No records) | `/api/resource/Delivery%20Note` |
| Delivery Note Item | Child Table | (Child of parent doc) | `/api/resource/Delivery%20Note%20Item` |
| Delivery Settings | Single | Delivery Settings | `GET /api/resource/Delivery%20Settings/Delivery%20Settings` |
| Delivery Stop | Child Table | (Child of parent doc) | `/api/resource/Delivery%20Stop` |
| Delivery Trip | Submittable | (No records) | `/api/resource/Delivery%20Trip` |
| Inventory Dimension | Standard | (No records) | `/api/resource/Inventory%20Dimension` |
| Item | Standard | (No records) | `/api/resource/Item` |
| Item Alternative | Standard | (No records) | `/api/resource/Item%20Alternative` |
| Item Attribute | Standard | Size, Colour | `/api/resource/Item%20Attribute` |
| Item Attribute Value | Child Table | (Child of parent doc) | `/api/resource/Item%20Attribute%20Value` |
| Item Barcode | Child Table | (Child of parent doc) | `/api/resource/Item%20Barcode` |
| Item Customer Detail | Child Table | (Child of parent doc) | `/api/resource/Item%20Customer%20Detail` |
| Item Default | Child Table | (Child of parent doc) | `/api/resource/Item%20Default` |
| Item Manufacturer | Standard | (No records) | `/api/resource/Item%20Manufacturer` |
| Item Price | Standard | (No records) | `/api/resource/Item%20Price` |
| Item Quality Inspection Parameter | Child Table | (Child of parent doc) | `/api/resource/Item%20Quality%20Inspection%20Parameter` |
| Item Reorder | Child Table | (Child of parent doc) | `/api/resource/Item%20Reorder` |
| Item Supplier | Child Table | (Child of parent doc) | `/api/resource/Item%20Supplier` |
| Item Tax | Child Table | (Child of parent doc) | `/api/resource/Item%20Tax` |
| Item Variant | Child Table | (Child of parent doc) | `/api/resource/Item%20Variant` |
| Item Variant Attribute | Child Table | (Child of parent doc) | `/api/resource/Item%20Variant%20Attribute` |
| Item Variant Settings | Single | Item Variant Settings | `GET /api/resource/Item%20Variant%20Settings/Item%20Variant%20Settings` |
| Item Website Specification | Child Table | (Child of parent doc) | `/api/resource/Item%20Website%20Specification` |
| Landed Cost Item | Child Table | (Child of parent doc) | `/api/resource/Landed%20Cost%20Item` |
| Landed Cost Purchase Receipt | Child Table | (Child of parent doc) | `/api/resource/Landed%20Cost%20Purchase%20Receipt` |
| Landed Cost Taxes and Charges | Child Table | (Child of parent doc) | `/api/resource/Landed%20Cost%20Taxes%20and%20Charges` |
| Landed Cost Voucher | Submittable | (No records) | `/api/resource/Landed%20Cost%20Voucher` |
| Manufacturer | Standard | (No records) | `/api/resource/Manufacturer` |
| Material Request | Submittable | (No records) | `/api/resource/Material%20Request` |
| Material Request Item | Child Table | (Child of parent doc) | `/api/resource/Material%20Request%20Item` |
| Packed Item | Child Table | (Child of parent doc) | `/api/resource/Packed%20Item` |
| Packing Slip | Submittable | (No records) | `/api/resource/Packing%20Slip` |
| Packing Slip Item | Child Table | (Child of parent doc) | `/api/resource/Packing%20Slip%20Item` |
| Pick List | Submittable | (No records) | `/api/resource/Pick%20List` |
| Pick List Item | Child Table | (Child of parent doc) | `/api/resource/Pick%20List%20Item` |
| Price List | Standard | Standard Buying, Standard Selling | `/api/resource/Price%20List` |
| Price List Country | Child Table | (Child of parent doc) | `/api/resource/Price%20List%20Country` |
| Purchase Receipt | Submittable | (No records) | `/api/resource/Purchase%20Receipt` |
| Purchase Receipt Item | Child Table | (Child of parent doc) | `/api/resource/Purchase%20Receipt%20Item` |
| Putaway Rule | Standard | (No records) | `/api/resource/Putaway%20Rule` |
| Quality Inspection | Submittable | (No records) | `/api/resource/Quality%20Inspection` |
| Quality Inspection Parameter | Standard | (No records) | `/api/resource/Quality%20Inspection%20Parameter` |
| Quality Inspection Parameter Group | Standard | (No records) | `/api/resource/Quality%20Inspection%20Parameter%20Group` |
| Quality Inspection Reading | Child Table | (Child of parent doc) | `/api/resource/Quality%20Inspection%20Reading` |
| Quality Inspection Template | Standard | (No records) | `/api/resource/Quality%20Inspection%20Template` |
| Quick Stock Balance | Single | Quick Stock Balance | `GET /api/resource/Quick%20Stock%20Balance/Quick%20Stock%20Balance` |
| Repost Item Valuation | Submittable | (No records) | `/api/resource/Repost%20Item%20Valuation` |
| Serial No | Standard | (No records) | `/api/resource/Serial%20No` |
| Shipment | Submittable | (No records) | `/api/resource/Shipment` |
| Shipment Delivery Note | Child Table | (Child of parent doc) | `/api/resource/Shipment%20Delivery%20Note` |
| Shipment Parcel | Child Table | (Child of parent doc) | `/api/resource/Shipment%20Parcel` |
| Shipment Parcel Template | Standard | (No records) | `/api/resource/Shipment%20Parcel%20Template` |
| Stock Entry | Submittable | (No records) | `/api/resource/Stock%20Entry` |
| Stock Entry Detail | Child Table | (Child of parent doc) | `/api/resource/Stock%20Entry%20Detail` |
| Stock Entry Type | Standard | Material Issue, Material Receipt | `/api/resource/Stock%20Entry%20Type` |
| Stock Ledger Entry | Standard | (No records) | `/api/resource/Stock%20Ledger%20Entry` |
| Stock Reconciliation | Submittable | (No records) | `/api/resource/Stock%20Reconciliation` |
| Stock Reconciliation Item | Child Table | (Child of parent doc) | `/api/resource/Stock%20Reconciliation%20Item` |
| Stock Reposting Settings | Single | Stock Reposting Settings | `GET /api/resource/Stock%20Reposting%20Settings/Stock%20Reposting%20Settings` |
| Stock Settings | Single | Stock Settings | `GET /api/resource/Stock%20Settings/Stock%20Settings` |
| UOM Category | Standard | Length, Area | `/api/resource/UOM%20Category` |
| UOM Conversion Detail | Child Table | (Child of parent doc) | `/api/resource/UOM%20Conversion%20Detail` |
| Variant Field | Child Table | (Child of parent doc) | `/api/resource/Variant%20Field` |
| Warehouse | Standard | All Warehouses - 98LABS, Stores - 98LABS | `/api/resource/Warehouse` |
| Warehouse Type | Standard | Transit | `/api/resource/Warehouse%20Type` |

### Subcontracting

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Subcontracting Order | Submittable | (No records) | `/api/resource/Subcontracting%20Order` |
| Subcontracting Order Item | Child Table | (Child of parent doc) | `/api/resource/Subcontracting%20Order%20Item` |
| Subcontracting Order Service Item | Child Table | (Child of parent doc) | `/api/resource/Subcontracting%20Order%20Service%20Item` |
| Subcontracting Order Supplied Item | Child Table | (Child of parent doc) | `/api/resource/Subcontracting%20Order%20Supplied%20Item` |
| Subcontracting Receipt | Submittable | (No records) | `/api/resource/Subcontracting%20Receipt` |
| Subcontracting Receipt Item | Child Table | (Child of parent doc) | `/api/resource/Subcontracting%20Receipt%20Item` |
| Subcontracting Receipt Supplied Item | Child Table | (Child of parent doc) | `/api/resource/Subcontracting%20Receipt%20Supplied%20Item` |

### Support

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Issue | Standard | (No records) | `/api/resource/Issue` |
| Issue Priority | Standard | Low, Medium | `/api/resource/Issue%20Priority` |
| Issue Type | Standard | (No records) | `/api/resource/Issue%20Type` |
| Pause SLA On Status | Child Table | (Child of parent doc) | `/api/resource/Pause%20SLA%20On%20Status` |
| SLA Fulfilled On Status | Child Table | (Child of parent doc) | `/api/resource/SLA%20Fulfilled%20On%20Status` |
| Service Day | Child Table | (Child of parent doc) | `/api/resource/Service%20Day` |
| Service Level Agreement | Standard | (No records) | `/api/resource/Service%20Level%20Agreement` |
| Service Level Priority | Child Table | (Child of parent doc) | `/api/resource/Service%20Level%20Priority` |
| Support Search Source | Child Table | (Child of parent doc) | `/api/resource/Support%20Search%20Source` |
| Support Settings | Single | Support Settings | `GET /api/resource/Support%20Settings/Support%20Settings` |
| Warranty Claim | Standard | (No records) | `/api/resource/Warranty%20Claim` |

### Telephony

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Call Log | Standard | (No records) | `/api/resource/Call%20Log` |
| Incoming Call Handling Schedule | Child Table | (Child of parent doc) | `/api/resource/Incoming%20Call%20Handling%20Schedule` |
| Incoming Call Settings | Standard | (No records) | `/api/resource/Incoming%20Call%20Settings` |
| Telephony Call Type | Submittable | (No records) | `/api/resource/Telephony%20Call%20Type` |
| Voice Call Settings | Standard | (No records) | `/api/resource/Voice%20Call%20Settings` |

### Utilities

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Rename Tool | Single | Rename Tool | `GET /api/resource/Rename%20Tool/Rename%20Tool` |
| SMS Log | Standard | (No records) | `/api/resource/SMS%20Log` |
| Video | Standard | (No records) | `/api/resource/Video` |
| Video Settings | Single | Video Settings | `GET /api/resource/Video%20Settings/Video%20Settings` |

### Website

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| About Us Settings | Single | About Us Settings | `GET /api/resource/About%20Us%20Settings/About%20Us%20Settings` |
| About Us Team Member | Child Table | (Child of parent doc) | `/api/resource/About%20Us%20Team%20Member` |
| Blog Category | Standard | general | `/api/resource/Blog%20Category` |
| Blog Post | Standard | welcome | `/api/resource/Blog%20Post` |
| Blog Settings | Single | Blog Settings | `GET /api/resource/Blog%20Settings/Blog%20Settings` |
| Blogger | Standard | brian | `/api/resource/Blogger` |
| Color | Standard | (No records) | `/api/resource/Color` |
| Company History | Child Table | (Child of parent doc) | `/api/resource/Company%20History` |
| Contact Us Settings | Single | Contact Us Settings | `GET /api/resource/Contact%20Us%20Settings/Contact%20Us%20Settings` |
| Discussion Reply | Standard | (No records) | `/api/resource/Discussion%20Reply` |
| Discussion Topic | Standard | (No records) | `/api/resource/Discussion%20Topic` |
| Help Article | Standard | (No records) | `/api/resource/Help%20Article` |
| Help Category | Standard | (No records) | `/api/resource/Help%20Category` |
| Personal Data Deletion Request | Standard | (No records) | `/api/resource/Personal%20Data%20Deletion%20Request` |
| Personal Data Deletion Step | Child Table | (Child of parent doc) | `/api/resource/Personal%20Data%20Deletion%20Step` |
| Personal Data Download Request | Standard | (No records) | `/api/resource/Personal%20Data%20Download%20Request` |
| Portal Menu Item | Child Table | (Child of parent doc) | `/api/resource/Portal%20Menu%20Item` |
| Portal Settings | Single | Portal Settings | `GET /api/resource/Portal%20Settings/Portal%20Settings` |
| Social Link Settings | Child Table | (Child of parent doc) | `/api/resource/Social%20Link%20Settings` |
| Top Bar Item | Child Table | (Child of parent doc) | `/api/resource/Top%20Bar%20Item` |
| Web Form | Standard | tasks, addresses | `/api/resource/Web%20Form` |
| Web Form Field | Child Table | (Child of parent doc) | `/api/resource/Web%20Form%20Field` |
| Web Form List Column | Child Table | (Child of parent doc) | `/api/resource/Web%20Form%20List%20Column` |
| Web Page | Standard | (No records) | `/api/resource/Web%20Page` |
| Web Page Block | Child Table | (Child of parent doc) | `/api/resource/Web%20Page%20Block` |
| Web Page View | Standard | (No records) | `/api/resource/Web%20Page%20View` |
| Web Template | Standard | Standard Navbar, Standard Footer | `/api/resource/Web%20Template` |
| Web Template Field | Child Table | (Child of parent doc) | `/api/resource/Web%20Template%20Field` |
| Website Meta Tag | Child Table | (Child of parent doc) | `/api/resource/Website%20Meta%20Tag` |
| Website Route Meta | Standard | (No records) | `/api/resource/Website%20Route%20Meta` |
| Website Route Redirect | Child Table | (Child of parent doc) | `/api/resource/Website%20Route%20Redirect` |
| Website Script | Single | Website Script | `GET /api/resource/Website%20Script/Website%20Script` |
| Website Settings | Single | Website Settings | `GET /api/resource/Website%20Settings/Website%20Settings` |
| Website Sidebar | Standard | (No records) | `/api/resource/Website%20Sidebar` |
| Website Sidebar Item | Child Table | (Child of parent doc) | `/api/resource/Website%20Sidebar%20Item` |
| Website Slideshow | Standard | (No records) | `/api/resource/Website%20Slideshow` |
| Website Slideshow Item | Child Table | (Child of parent doc) | `/api/resource/Website%20Slideshow%20Item` |
| Website Theme | Standard | Standard | `/api/resource/Website%20Theme` |
| Website Theme Ignore App | Child Table | (Child of parent doc) | `/api/resource/Website%20Theme%20Ignore%20App` |

### Workflow

| DocType | Type | Sample Names | API Endpoints |
|---------|------|--------------|---------------|
| Workflow | Standard | (No records) | `/api/resource/Workflow` |
| Workflow Action | Standard | (No records) | `/api/resource/Workflow%20Action` |
| Workflow Action Master | Standard | Approve, Reject | `/api/resource/Workflow%20Action%20Master` |
| Workflow Action Permitted Role | Child Table | (Child of parent doc) | `/api/resource/Workflow%20Action%20Permitted%20Role` |
| Workflow Document State | Child Table | (Child of parent doc) | `/api/resource/Workflow%20Document%20State` |
| Workflow State | Standard | Pending, Approved | `/api/resource/Workflow%20State` |
| Workflow Transition | Child Table | (Child of parent doc) | `/api/resource/Workflow%20Transition` |

## Common Query Parameters

### For List Endpoints

| Parameter | Description | Example |
|-----------|-------------|---------|
| `fields` | Select specific fields | `fields=["name","status"]` |
| `filters` | Filter results | `filters=[["status","=","Active"]]` |
| `limit_start` | Pagination offset | `limit_start=0` |
| `limit_page_length` | Page size | `limit_page_length=20` |
| `order_by` | Sort results | `order_by=modified desc` |

## Examples

### Get list with filters
```bash
curl -b cookies.txt \
  "http://localhost:8080/api/resource/Item?filters=[[\"item_group\",\"=\",\"Products\"]]&fields=[\"item_code\",\"item_name\"]"
```

### Get single document
```bash
curl -b cookies.txt \
  "http://localhost:8080/api/resource/User/Administrator"
```

### Create new document
```bash
curl -b cookies.txt -X POST \
  -H "Content-Type: application/json" \
  -d '{"doctype":"Item","item_code":"TEST-001","item_name":"Test Item","item_group":"Products","stock_uom":"Nos"}' \
  "http://localhost:8080/api/resource/Item"
```

### Update document
```bash
curl -b cookies.txt -X PUT \
  -H "Content-Type: application/json" \
  -d '{"item_name":"Updated Test Item"}' \
  "http://localhost:8080/api/resource/Item/TEST-001"
```

### Delete document
```bash
curl -b cookies.txt -X DELETE \
  "http://localhost:8080/api/resource/Item/TEST-001"
```

## Special Endpoints

### Authentication
- `POST /api/method/login` - Login
- `POST /api/method/logout` - Logout

### File Operations
- `POST /api/method/upload_file` - Upload files
- `GET /api/method/download_file` - Download files

### Reports
- `GET /api/method/frappe.desk.query_report.run` - Run reports

## DocType Categories

### Single DocTypes
These DocTypes have only one record (singleton pattern):

- About Us Settings
- Accounts Settings
- Appointment Booking Settings
- Authorization Control
- BOM Update Tool
- Bank Clearance
- Bank Reconciliation Tool
- Blog Settings
- Bulk Update
- Buying Settings
- CRM Settings
- Chart of Accounts Importer
- Contact Us Settings
- Currency Exchange Settings
- Customize Form
- Data Export
- Delivery Settings
- Document Naming Settings
- Domain Settings
- Dropbox Settings
- ... and 47 more

### Child Tables
These DocTypes are child tables and cannot be accessed directly:

- About Us Team Member
- Accounting Dimension Detail
- Advance Tax
- Advance Taxes and Charges
- Allowed Dimension
- Allowed To Transact With
- Applicable On Account
- Appointment Booking Slots
- Asset Capitalization Asset Item
- Asset Capitalization Service Item
- Asset Capitalization Stock Item
- Asset Category Account
- Asset Finance Book
- Asset Maintenance Task
- Asset Movement Item
- Asset Repair Consumed Item
- Assignment Rule Day
- Assignment Rule User
- Auto Repeat Day
- Availability Of Slots
- ... and 292 more

### Submittable DocTypes
These DocTypes support document submission workflow:

- Asset
- Asset Capitalization
- Asset Maintenance Log
- Asset Movement
- Asset Repair
- Asset Value Adjustment
- BOM
- BOM Update Log
- Bank Guarantee
- Bank Transaction
- Blanket Order
- Budget
- Cashier Closing
- Contract
- Contract Fulfilment Checklist
- Cost Center Allocation
- Delivery Note
- Delivery Trip
- Dunning
- Exchange Rate Revaluation
- ... and 57 more

## Important Notes

1. **URL Encoding**: DocType names with spaces must be URL encoded (e.g., "Sales Order" → "Sales%20Order")
2. **Permissions**: Access to DocTypes depends on user permissions
3. **Rate Limiting**: Default rate limit is 60 requests per minute
4. **Single DocTypes**: Use the DocType name as both the resource and document name
5. **Child Tables**: Cannot be accessed directly, only through their parent document
6. **Submittable Documents**: Support additional states (Draft, Submitted, Cancelled)
