import { describe, it, expect } from 'vitest';

export function calculateStayPricing(params: {
  nightlyRateInr: number;
  nights: number;
  addonsTotalInr: number;
  applyDirectBenefit: boolean;
  promoPercent: number;
  isIntraStateKarnataka: boolean;
}) {
  const roomSubtotal = params.nightlyRateInr * params.nights;
  const directDiscount = params.applyDirectBenefit ? Math.round(roomSubtotal * 0.10) : 0;
  const promoDiscount = Math.round((roomSubtotal - directDiscount) * (params.promoPercent / 100));
  const taxableRoom = Math.max(0, roomSubtotal - directDiscount - promoDiscount);
  const taxableTotal = taxableRoom + params.addonsTotalInr;

  // India GST 2026 rule: <= 7500/night is 5% without ITC; > 7500/night is 18% with ITC
  const effectiveNightlyTariff = taxableRoom / Math.max(1, params.nights);
  const gstRatePct = effectiveNightlyTariff > 7500 ? 18 : 5;
  const totalGst = Math.round(taxableTotal * (gstRatePct / 100));

  return {
    roomSubtotal,
    directDiscount,
    promoDiscount,
    taxableTotal,
    gstRatePct,
    cgst: params.isIntraStateKarnataka ? totalGst / 2 : 0,
    sgst: params.isIntraStateKarnataka ? totalGst / 2 : 0,
    igst: params.isIntraStateKarnataka ? 0 : totalGst,
    grandTotal: taxableTotal + totalGst,
  };
}

export function calculatePolicyRefund(totalPaidInr: number, hoursBeforeCheckIn: number) {
  if (hoursBeforeCheckIn >= 168) {
    return { penaltyInr: 0, refundInr: totalPaidInr, tier: 'Full Refund (>= 7 days)' };
  }
  if (hoursBeforeCheckIn >= 48) {
    const penaltyInr = Math.round(totalPaidInr * 0.5);
    return { penaltyInr, refundInr: totalPaidInr - penaltyInr, tier: '50% Policy Refund (48h - 168h)' };
  }
  return { penaltyInr: totalPaidInr, refundInr: 0, tier: 'Non-Refundable Window (< 48h)' };
}

describe('Aurelia Sage Retreat — Financial, Tax & Operations Unit Tests', () => {
  it('applies 18% GST split into 9% CGST + 9% SGST for luxury villas above ₹7,500/night', () => {
    const res = calculateStayPricing({
      nightlyRateInr: 18000,
      nights: 3,
      addonsTotalInr: 4500,
      applyDirectBenefit: true,
      promoPercent: 0,
      isIntraStateKarnataka: true,
    });
    expect(res.roomSubtotal).toBe(54000);
    expect(res.directDiscount).toBe(5400);
    expect(res.taxableTotal).toBe(53100);
    expect(res.gstRatePct).toBe(18);
    expect(res.cgst).toBe(4779);
    expect(res.sgst).toBe(4779);
    expect(res.grandTotal).toBe(62658);
  });

  it('applies 5% GST slab when effective nightly tariff is ₹7,500 or below', () => {
    const res = calculateStayPricing({
      nightlyRateInr: 7000,
      nights: 2,
      addonsTotalInr: 0,
      applyDirectBenefit: false,
      promoPercent: 0,
      isIntraStateKarnataka: false,
    });
    expect(res.gstRatePct).toBe(5);
    expect(res.igst).toBe(700);
    expect(res.grandTotal).toBe(14700);
  });

  it('computes policy-driven cancellation refunds accurately', () => {
    expect(calculatePolicyRefund(50000, 200).refundInr).toBe(50000);
    expect(calculatePolicyRefund(50000, 72).refundInr).toBe(25000);
    expect(calculatePolicyRefund(50000, 24).refundInr).toBe(0);
  });
});
