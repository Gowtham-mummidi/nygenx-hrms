import { jsPDF } from 'jspdf'
import autoTablePlugin from 'jspdf-autotable'
import type { Payroll } from '@/lib/database.types'

const autoTable = typeof autoTablePlugin === 'function' ? autoTablePlugin : (autoTablePlugin as any).default

function formatDOJ(dateStr?: string | null): string {
  if (!dateStr) return '-'
  try {
    const d = new Date(dateStr)
    if (isNaN(d.getTime())) return dateStr
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    const day = String(d.getDate()).padStart(2, '0')
    const mon = months[d.getMonth()]
    const yy = String(d.getFullYear()).slice(-2)
    return `${day}-${mon}-${yy}`
  } catch {
    return dateStr
  }
}

function getMonthYearHeader(payPeriod?: string): string {
  if (!payPeriod) return '-'
  const [y, m] = payPeriod.split('-')
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ]
  const mIndex = parseInt(m, 10) - 1
  const monthName = months[mIndex] || ''
  return `${monthName}-${y || ''}`
}

const NYGENX_LOGO_DATA_URL = 'data:image/png;base64,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'

export function generatePayslipPdfDoc(p: Payroll): jsPDF {
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' })
  const margin = 14
  const pageWidth = doc.internal.pageSize.getWidth()
  const contentWidth = pageWidth - (margin * 2)
  const startY = margin

  // 1. Header Box
  const headerHeight = 22

  // Draw official OCLUT logo image
  try {
    doc.addImage(NYGENX_LOGO_DATA_URL, 'PNG', margin + 3, startY + 2, 18, 18)
  } catch {
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(26)
    doc.setTextColor(0, 163, 255)
    doc.text('NYGENX', margin + 3, startY + 14)
  }

  // Title: PAYSLIP FOR <Month-Year>
  const titleText = `PAYSLIP FOR ${getMonthYearHeader(p.pay_period)}`
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(11)
  doc.setTextColor(0, 0, 0)
  const titleX = pageWidth / 2 + 10
  const titleY = startY + 15
  doc.text(titleText, titleX, titleY, { align: 'center' })

  // Underline
  const textWidth = doc.getTextWidth(titleText)
  doc.setDrawColor(0, 0, 0)
  doc.setLineWidth(0.4)
  doc.line(titleX - (textWidth / 2), titleY + 1.2, titleX + (textWidth / 2), titleY + 1.2)

  // Divider line separating header from Table 1
  doc.line(margin, startY + headerHeight, margin + contentWidth, startY + headerHeight)

  // Extract Employee Meta - Real data, no hardcoded placeholders
  const emp = p.employee
  const empCode = emp?.employee_code || (emp as any)?.id?.slice(0, 8) || '-'
  const empName = emp?.first_name ? `${emp.first_name} ${emp.last_name || ''}`.trim() : (emp?.employee_code || '-')
  const doj = formatDOJ(emp?.joining_date)
  const bankName = (p as any).bank_name || emp?.bank_name || ((emp as any)?.bank_account_number || emp?.bank_account ? (emp?.bank_name || 'Bank Account') : '-')
  const panNo = emp?.pan_number || (emp as any)?.pan_no || (p as any).pan_no || '-'
  const bankAccNo = (p as any).bank_account || emp?.bank_account_number || emp?.bank_account || (emp as any)?.account_number || '-'
  
  const totalDays = p.total_days || 31
  const daysPaid = typeof p.present_days === 'number' ? p.present_days : totalDays
  const daysLop = Math.max(0, totalDays - daysPaid)
  
  const designation = (emp?.designation as any)?.name || (emp as any)?.designation || '-'
  const uanNo = emp?.uan_number || (emp as any)?.uan_no || '-'
  const department = (emp?.department as any)?.name || (emp as any)?.department || '-'
  const pfNo = emp?.pf_number || (emp as any)?.pf_no || '-'

  const colWidthLabel = 34
  const colWidthVal = (contentWidth - (colWidthLabel * 2)) / 2

  // Table 1: Employee Details
  autoTable(doc, {
    startY: startY + headerHeight,
    margin: { left: margin, right: margin },
    tableWidth: contentWidth,
    theme: 'grid',
    styles: {
      fontSize: 8.5,
      textColor: [0, 0, 0],
      lineColor: [0, 0, 0],
      lineWidth: 0.35,
      cellPadding: { top: 1.8, bottom: 1.8, left: 2.5, right: 2.5 },
      font: 'helvetica',
      valign: 'middle',
    },
    columnStyles: {
      0: { cellWidth: colWidthLabel, fontStyle: 'normal' },
      1: { cellWidth: colWidthVal, fontStyle: 'normal' },
      2: { cellWidth: colWidthLabel, fontStyle: 'normal' },
      3: { cellWidth: colWidthVal, fontStyle: 'normal' },
    },
    body: [
      ['Employee Code', empCode, 'Employee Name', empName],
      ['D.O.J.', doj, 'Bank Name', bankName],
      ['PAN No.', panNo, 'Bank A/c No', bankAccNo],
      ['Days paid for', String(daysPaid), 'Days for LOP', String(daysLop)],
      ['Designation', designation, 'UAN No', uanNo],
      ['Department', department, 'PF No', pfNo],
      ['', '', '', ''],
    ],
  })

  const finalY1 = (doc as any).lastAutoTable?.finalY ?? (startY + headerHeight + 40)

  // Earnings breakdown calculation - directly from payroll record
  const basic = Number(p.basic_salary) || 0
  const hra = Number(p.hra) || 0
  const totalAllowances = Number(p.allowances) || 0
  const bonus = Number(p.bonus) || 0

  let conveyance = 0
  let medical = 0
  let special = bonus

  if (totalAllowances > 0) {
    if (totalAllowances >= 3250) {
      conveyance = 2000
      medical = 1250
      special = (totalAllowances - 3250) + bonus
    } else {
      conveyance = Number((totalAllowances * 0.5).toFixed(2))
      medical = Number((totalAllowances * 0.3).toFixed(2))
      special = Math.max(0, Number((totalAllowances - conveyance - medical + bonus).toFixed(2)))
    }
  }

  const grossEarnings = basic + hra + conveyance + medical + special

  // Deductions breakdown calculation
  const pt = (Number(p.deductions) > 0 || (basic + hra) >= 15000) ? 200 : 0
  const it = Number(p.tax) || 0
  const pf = Number(p.provident_fund) || 0
  const others = Math.max(0, Number(p.deductions) - pt)
  const grossDeductions = pt + it + pf + others
  const netPay = typeof p.net_salary === 'number' && (p.net_salary > 0 || (grossEarnings === 0 && grossDeductions === 0))
    ? p.net_salary
    : Math.max(0, grossEarnings - grossDeductions)

  const colEarnLabel = 44
  const colEarnVal = (contentWidth / 2) - colEarnLabel
  const colDedLabel = 44
  const colDedVal = (contentWidth / 2) - colDedLabel

  // Table 2: Earnings & Deductions Grid
  autoTable(doc, {
    startY: finalY1,
    margin: { left: margin, right: margin },
    tableWidth: contentWidth,
    theme: 'grid',
    styles: {
      fontSize: 8.5,
      textColor: [0, 0, 0],
      lineColor: [0, 0, 0],
      lineWidth: 0.35,
      cellPadding: { top: 1.8, bottom: 1.8, left: 2.5, right: 2.5 },
      font: 'helvetica',
      valign: 'middle',
    },
    columnStyles: {
      0: { cellWidth: colEarnLabel, fontStyle: 'normal' },
      1: { cellWidth: colEarnVal, halign: 'right', fontStyle: 'normal' },
      2: { cellWidth: colDedLabel, fontStyle: 'normal' },
      3: { cellWidth: colDedVal, halign: 'right', fontStyle: 'normal' },
    },
    body: [
      ['Basic', basic.toFixed(2), 'Professional Tax', pt.toFixed(2)],
      ['HRA', hra.toFixed(2), 'Income Tax', it.toFixed(2)],
      ['Conveyance', conveyance.toFixed(2), 'Provident Fund', pf.toFixed(2)],
      ['Medical Allowance', medical.toFixed(2), 'Others', others.toFixed(2)],
      ['Special Allowance', special.toFixed(2), '', ''],
      [
        { content: 'Gross Earnings', styles: { fontStyle: 'bold' } },
        { content: grossEarnings.toFixed(2), styles: { fontStyle: 'bold', halign: 'right' } },
        { content: 'Gross Deductions', styles: { fontStyle: 'bold' } },
        { content: grossDeductions.toFixed(2), styles: { fontStyle: 'bold', halign: 'right' } },
      ],
      [
        {
          content: `Net Pay    Rs. ${netPay.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`,
          colSpan: 4,
          styles: { fontStyle: 'bold', cellPadding: { top: 2.5, bottom: 2.5, left: 2.5, right: 2.5 } }
        }
      ]
    ],
  })

  const finalY2 = (doc as any).lastAutoTable?.finalY ?? (finalY1 + 60)

  // Outer Box Border
  doc.setLineWidth(0.6)
  doc.setDrawColor(0, 0, 0)
  doc.rect(margin, startY, contentWidth, finalY2 - startY)

  return doc
}

export function downloadPayslipPdf(p: Payroll) {
  const doc = generatePayslipPdfDoc(p)
  const code = p.employee?.employee_code || 'employee'
  const period = p.pay_period || 'payslip'
  doc.save(`Payslip_${code}_${period}.pdf`)
}
