import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function tag(block: string, name: string): string {
  const match = block.match(new RegExp(`<${name}>([^<]*)</${name}>`, 'i'))
  return (match?.[1] ?? '').trim()
}

function num(value: string): number {
  if (!value) return 0
  const n = Number(value.replace(',', '.'))
  return Number.isFinite(n) ? n : 0
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    let body: Record<string, unknown> = {}
    try { body = await req.json() } catch (_) {}
    const wanted = Array.isArray(body.dovizler)
      ? body.dovizler.map((x) => String(x).toUpperCase())
      : ['USD', 'EUR', 'GBP', 'CHF', 'JPY']

    const tcmb = await fetch('https://www.tcmb.gov.tr/kurlar/today.xml', {
      headers: { 'User-Agent': 'UNAL-YEDEK-PARCA-ERP/2.2' },
    })
    if (!tcmb.ok) throw new Error(`TCMB HTTP ${tcmb.status}`)
    const xml = await tcmb.text()

    const dateMatch = xml.match(/Tarih="([^"]+)"/i)
    const rawDate = dateMatch?.[1] ?? '' // mm/dd/yyyy
    const parts = rawDate.split('/')
    const tarih = parts.length === 3
      ? `${parts[2]}-${parts[0].padStart(2, '0')}-${parts[1].padStart(2, '0')}`
      : new Date().toISOString().slice(0, 10)

    const rows: Record<string, unknown>[] = []
    const currencyRegex = /<Currency\b([^>]*)>([\s\S]*?)<\/Currency>/gi
    let m: RegExpExecArray | null
    while ((m = currencyRegex.exec(xml)) !== null) {
      const attrs = m[1]
      const block = m[2]
      const code = (attrs.match(/CurrencyCode="([^"]+)"/i)?.[1] ?? '').toUpperCase()
      if (!wanted.includes(code)) continue
      const unit = Math.max(1, num(tag(block, 'Unit')) || 1)
      // ERP hesaplarında her zaman 1 döviz birimi karşılığı TL saklanır.
      rows.push({
        tarih,
        para_birimi: code,
        birim: unit,
        alis: num(tag(block, 'ForexBuying')) / unit,
        satis: num(tag(block, 'ForexSelling')) / unit,
        efektif_alis: num(tag(block, 'BanknoteBuying')) / unit,
        efektif_satis: num(tag(block, 'BanknoteSelling')) / unit,
        kaynak: 'TCMB',
        guncellenme_tarihi: new Date().toISOString(),
      })
    }

    if (rows.length === 0) throw new Error('TCMB XML içinde istenen dövizler bulunamadı.')

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, serviceRole)
    const { error } = await supabase
      .from('erp_doviz_kurlari')
      .upsert(rows, { onConflict: 'tarih,para_birimi' })
    if (error) throw error

    return new Response(JSON.stringify({ ok: true, tarih, kaydedilen: rows.length, kurlar: rows }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8' },
    })
  }
})
