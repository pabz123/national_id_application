# National ID Application Module

An Odoo 19 module for processing online national ID applications with a public web interface and backend approval workflow.

## Features

### Public Interface
- **Web Application Form**: Citizens can apply online at `/national-id/apply`
- **File Upload Support**: Upload passport photo and LC reference letter
- **Auto-numbering**: Applications get unique reference numbers (e.g., NID/2026/0001)

### Backend Workflow
- **Two-Stage Approval Process**:
  - Stage 1 Review → Stage 1 Approved
  - Stage 2 Review → Final Approval
- **Chatter Integration**: All approvals logged automatically
- **Rejection Handling**: Applications can be rejected with reasons
- **Reset Capability**: Rejected applications can be reset

### Application Fields
- Full Name
- Date of Birth
- Gender
- Nationality
- Existing National ID (for renewals)
- District of Origin
- Phone Number
- Email Address
- Passport Photo (required)
- LC Reference Letter (required)

## Installation

1. Copy this module to your Odoo `addons` directory
2. Restart Odoo server
3. Go to **Apps** → **Update Apps List**
4. Search for "National ID Application"
5. Click **Install**

## Usage

### For Citizens
Visit: `http://your-odoo-domain/national-id/apply`

### For Officers
Navigate to: **National ID** → **Applications** → **All Applications**

## Technical Details

- **Odoo Version**: 19.0
- **License**: LGPL-3
- **Dependencies**: base, mail, web, portal

## Author

Precious Mulungi Pabire  
Software & Functional Developer Intern  
Kola Technologies
