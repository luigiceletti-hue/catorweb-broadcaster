#!/usr/bin/env liquidsoap
# Catorweb Broadcaster — Edizione distribuibile — Liquidsoap 2.2.x (Windows)
# Suona la libreria locale e la manda al server di streaming scelto in
# Impostazioni (Icecast, Shoutcast o ingresso live Liquidsoap/harbor).
#
# QUESTO E' UN MODELLO: il server Python sostituisce i segnaposto @@...@@ con
# i valori di config.json e lancia la copia scritta in %APPDATA%\CatorwebPC\data.
# Argomenti: -- <cartella data> <porta app> <host> <telnet> <monitor> <mic> <registrazioni>

data_dir = string.replace(pattern="\\\\", fun (_) -> "/", argv(default="../data", 1))
app_port = argv(default="8767", 2)
monitor_port = int_of_string(default=8001, argv(default="8001", 5))

# ── Destinazione: server di streaming (da Impostazioni) ───────────────────
vps_host     = argv(default="", 3)
vps_port     = @@PORT@@
vps_password = "@@PASSWORD@@"

log.level := 3
log.file  := true
log.file.path := "#{data_dir}/logs/liquidsoap.log"
log.stdout := true

settings.harbor.bind_addrs := ["127.0.0.1"]
settings.server.telnet := true
settings.server.telnet.port := int_of_string(default=1235, argv(default="1235", 4))
settings.server.telnet.bind_addr := "127.0.0.1"

# ── Si spegne da solo se il server Python non risponde più ────────────────
# (finestra chiusa / crash): così il PC non resta in onda sul VPS senza controllo.
app_misses = ref(0)
def check_app() =
  ok = try
    r = http.get("http://127.0.0.1:#{app_port}/api/public/nowplaying", timeout=3.)
    r.status_code == 200
  catch _ do
    false
  end
  if ok then app_misses := 0 else app_misses := app_misses() + 1 end
  if app_misses() >= 3 then
    log("APP: server Catorweb non raggiungibile, spengo Liquidsoap")
    shutdown()
  end
end
thread.run(delay=20., every=5., check_app)

# ── Coda utente: Python invia brani via telnet (user_queue.push <path>) ──
user_queue = request.queue(id="user_queue")
# "user_queue.flush" non esiste in Liquidsoap 2.2: senza questo "↺ Sostituisci coda" lasciava
# i brani vecchi davanti ai nuovi. Svuota la coda, il brano in onda finisce normalmente.
server.register(namespace="user_queue", description="Svuota la coda (il brano in onda continua)", "flush",
  fun (_) -> begin user_queue.set_queue([]); "OK" end)

# ── Clockwheel dinamico: Liquidsoap chiede a Python il prossimo brano ──
def cw_next() =
  try
    r    = http.get("http://127.0.0.1:#{app_port}/api/liquidsoap/next_track", timeout=5.)
    path = string.trim(r)
    if r.status_code == 200 and path != "" then
      null(request.create(path))
    else
      null()
    end
  catch _ do
    null()
  end
end

# Non request.dynamic: su Windows dopo un passaggio user_queue -> clockwheel
# smetteva di chiedere brani (silenzio). Qui una coda viene rabboccata ogni
# 2s, così c'è sempre un brano del clockwheel già pronto in attesa.
clockwheel = request.queue(id="clockwheel")
cw_busy = ref(false)
def cw_fill() =
  if not cw_busy() and list.length(clockwheel.queue()) < 1 then
    cw_busy := true
    r = cw_next()
    if null.defined(r) then clockwheel.push(null.get(r)) end
    cw_busy := false
  end
end
thread.run(delay=1., every=2., cw_fill)

# ── Regia manuale (16/10/2026) ──────────────────────────────────────────────
# Automatico: coda utente prima, poi clockwheel (come sempre).
# Manuale  : il clockwheel si ferma; a fine brano NON parte niente; "AVVIA"
#            (manual.go) fa partire il primo della coda/scaletta. AVVIA mentre
#            un brano suona = passa subito al prossimo (dissolvenza normale).
# I passaggi avvengono a fine brano (switch track_sensitive): niente tagli.
# Provato isolato: test_clock/manual.liq + manual_run.py.
manual_mode = ref(false)
manual_go = ref(false)
def manual_write() =
  file.write(data=(if manual_mode() then "on" else "off" end), "#{data_dir}/manual_mode.txt")
end
manual_write()
# ── Jingle a STACCO (16/10/2026) ──────────────────────────────────────────
# Pulsante jingle in modo "stacco": la musica sfuma (1.2 s) e viene "tenuta"
# (stacco_hold: cancelli chiusi, nessun brano nuovo), il brano in corso salta e
# il jingle suona DA SOLO, fuori dal crossfade. Finito il jingle e spenta la
# coda del crossfade, si rilascia: in automatico parte il brano successivo
# dall'inizio, in manuale silenzio fino ad AVVIA.
# Misurato: la dissolvenza va DOPO il crossfade (che legge ~3 s in anticipo) e
# il jingle non deve passare dal crossfade (la coda del brano saltato tornava
# a volume pieno sotto il jingle).
stacco_hold = ref(false)
stacco_phase = ref(0)          # 0 fermo, 1 dissolvenza, 2 jingle in onda
# "Chiudi a fine brano" (17/10/2026): fine.arm chiude il cancello end_gate (piu' sotto), il brano
# in onda finisce normalmente e poi non parte piu' niente; il server Python vede il
# silenzio (e il mic spento) e chiude la diretta. fine.cancel annulla.
end_armed = ref(false)
q_gate = switch(id="manual_gate", track_sensitive=true,
  [({(not manual_mode() or manual_go()) and not stacco_hold()}, user_queue)])
q_gate = source.on_track(q_gate, fun (_) -> if manual_mode() then manual_go := false end)
cw_gate = switch(id="auto_gate", track_sensitive=true,
  [({not manual_mode() and not stacco_hold()}, clockwheel)])
server.register(namespace="fine", description="Chiudi la diretta a fine brano: niente brani dopo questo", "arm",
  fun (_) -> begin end_armed := true; log("FINE DIRETTA: a fine brano"); "armed" end)
server.register(namespace="fine", description="Annulla la chiusura a fine brano", "cancel",
  fun (_) -> begin end_armed := false; log("FINE DIRETTA: annullata"); "cancelled" end)
server.register(namespace="fine", description="armed|off", "status",
  fun (_) -> if end_armed() then "armed" else "off" end)
main_src = fallback(id="radio_main", track_sensitive=true, [q_gate, cw_gate])
# il cancello "fine diretta" sta DOPO la scelta dei brani: sui cancelli di coda/clockwheel non bastava,
# il clockwheel aveva gia' prenotato il brano successivo (prova 17/10: partiva lo stesso)
end_gate = switch(id="end_gate", track_sensitive=true, [({not end_armed()}, main_src)])
# Dissolvenza tra i brani: secondi da Impostazioni (0 = stacco secco, niente crossfade)
@@CROSSFADE@@
radio = rms(id="music_level", duration=0.2, radio)
music_level = radio
# quando la musica si ferma l'rms resta all'ultimo valore: conta anche is_ready
def music_on() = music_level.is_ready() and music_level.rms() > lin_of_dB(-60.) end
stacco_gain = ref(1.)
radio = amplify(id="stacco_fade", {stacco_gain()}, radio)
stacco_q = request.queue(id="stacco")
stacco_gate = switch(id="stacco_gate", track_sensitive=false, [({stacco_phase() == 2}, stacco_q)])
radio = add(id="music_plus_stacco", normalize=false, [radio, stacco_gate])
stacco_step = 0.02
stacco_t = ref(0.)
stacco_seen = ref(false)       # il jingle e' davvero partito
def stacco_start() =
  stacco_hold := true
  stacco_t := 0.
  stacco_seen := false
  stacco_phase := 2
  main_src.skip()
  log("JINGLE STACCO: via")
end
thread.run(every=stacco_step, fun () -> begin
  stacco_t := stacco_t() + stacco_step
  if stacco_phase() == 1 then
    g = stacco_gain() - stacco_step / 1.2
    if g > 0. then
      stacco_gain := g
    else
      stacco_gain := 0.
      # musica a zero: via quando il jingle e' pronto (max 5 s), niente buchi
      if stacco_q.is_ready() or stacco_t() > 6.2 then stacco_start() end
    end
  elsif stacco_phase() == 2 then
    if stacco_q.is_ready() then stacco_seen := true end
    # fine: jingle partito e finito (o fermato), coda del brano saltato spenta
    if (stacco_seen() and not stacco_q.is_ready()
        and (not music_on() or stacco_t() > 15.))
       or stacco_t() > 120. then
      stacco_phase := 0
      stacco_gain := 1.
      stacco_hold := false
      log("JINGLE STACCO: finito")
    end
  end
end)
radio = mksafe(radio)
# "sta suonando" = esce audio: il silenzio della regia manuale e' silenzio assoluto
# (is_ready/remaining non servono: in manuale il cancello e' chiuso anche mentre suona)
radio = rms(id="prog_level", duration=0.3, radio)
prog_level = radio
def is_playing() = prog_level.rms() > lin_of_dB(-80.) end
server.register(namespace="manual", description="Regia manuale ON", "on",
  fun (_) -> begin manual_mode := true; manual_write(); log("REGIA: manuale"); "on" end)
server.register(namespace="manual", description="Regia manuale OFF (automatico)", "off",
  fun (_) -> begin manual_mode := false; manual_go := false; manual_write(); log("REGIA: automatico"); "off" end)
server.register(namespace="manual", description="AVVIA il prossimo della scaletta", "go",
  fun (_) -> begin
    was_playing = is_playing()   # controllo PRIMA del via
    manual_go := true
    if was_playing then main_src.skip() end
    log("REGIA: AVVIA")
    "go"
  end)
# SKIP: salta SOLO il brano musicale. "stream_out.skip" (salto sull'uscita)
# si propagava a tutta la catena, compreso il grafo FFmpeg della voce, e
# mandava Liquidsoap in loop al 100% di CPU senza piu' rispondere ai comandi
# (trovato 16/10 provando la regia manuale; valeva anche per il ⏭ Skip normale).
server.register(namespace="music", description="Salta il brano musicale in onda", "skip",
  fun (_) -> begin main_src.skip(); "Done" end)
server.register(namespace="stacco", description="Jingle a stacco: sfuma la musica e parte il jingle", "play",
  fun (f) -> begin
    ignore(stacco_q.push(request.create(f)))
    # musica in onda: prima sfuma; in silenzio parte subito. Se un jingle a
    # stacco sta gia' suonando, questo si accoda e parte subito dopo.
    if stacco_phase() == 0 then
      stacco_t := 0.
      if music_on() then stacco_phase := 1 else stacco_start() end
    end
    log("JINGLE STACCO: #{f}")
    "ok"
  end)
server.register(namespace="manual", description="on|off playing|idle", "status",
  fun (_) -> "#{if manual_mode() then 'on' else 'off' end} #{if is_playing() then 'playing' else 'idle' end}")

# ── Nowplaying (letto dalla dashboard locale) ──────────────────────────────
def np_text(m) =
  fname  = m["filename"]
  title  = m["title"]
  artist = m["artist"]
  if artist != "" and title != "" then
    "#{artist} - #{title}"
  elsif title != "" then title
  elsif fname != "" then path.remove_extension(path.basename(fname))   # mai il percorso intero
  else "In onda"
  end
end

def write_nowplaying(m) =
  fname = m["filename"]
  np = np_text(m)
  log("NOWPLAYING: #{np}")
  file.write(data=np,    "#{data_dir}/nowplaying.txt")
  file.write(data=fname, "#{data_dir}/current_track.txt")
end

# Brano senza titolo nei tag (o con tag illeggibili): titolo = nome del file, senza cartelle
# ne' ".mp3". Prima agli ascoltatori e nell'app arrivava il percorso completo del PC.
def title_from_filename(m) =
  if m["title"] == "" and m["filename"] != "" then
    [("title", path.remove_extension(path.basename(m["filename"])))]
  else
    []
  end
end
radio = metadata.map(id="title_fallback", title_from_filename, radio)
radio = source.on_metadata(radio, write_nowplaying)
# il jingle a stacco entra con add(), che non passa i suoi metadati: "In onda" a mano
stacco_q.on_metadata(write_nowplaying)
radio = normalize(id="normalize", target=-14., radio)

# ── Microfono (Yeti) mescolato alla musica ─────────────────────────────────
# Comandi telnet dal server Python: mic.on / mic.off / mic.status.
# La voce va in onda con taglio bassi, un po' di presenza, compressore,
# volume regolabile e limitatore; la musica scende sotto la voce (vedi Ducking).
# Se lo Yeti non c'e' la musica va avanti normalmente (il mic riprova da solo).
# NB: niente filter.iir.* — in Liquidsoap 2.2.4 falliscono all'avvio con
# questo ingresso ("Early computation of source content-type").
mic_device = argv(default="-", 6)   # "-" = nessun microfono scelto in Impostazioni
mic_on = ref(false)
def mic_set(v) =
  mic_on := v
  file.write(data=(if v then "on" else "off" end), "#{data_dir}/mic_on.txt")
  log("MIC: #{if v then 'acceso' else 'spento' end}")
end
mic_set(false)
server.register(namespace="mic", description="Accende il microfono", "on",
                fun (_) -> begin mic_set(true); "on" end)
server.register(namespace="mic", description="Spegne il microfono", "off",
                fun (_) -> begin mic_set(false); "off" end)
server.register(namespace="mic", description="Stato del microfono", "status",
                fun (_) -> if mic_on() then "on" else "off" end)

@@MIC_INPUT@@
mic = buffer(id="mic_buf", fallible=true, buffer=0.2, max=1., mic)
mic = audio_to_stereo(mic)
mic = filter(id="mic_hp", freq=80., mode="high", q=0.7, mic)
mic = rms(id="mic_level", duration=0.05, mic)  # livello voce SENZA ritardo, prima del compressore
mic_level = mic
# La voce va in onda con 0.6 s di ritardo: il ducking (che usa il livello qui
# sopra, non ritardato) fa in tempo ad abbassare la musica PRIMA che arrivi
# la voce (16/10: "la musica si abbassa e si alza in ritardo, sembrano errori
# di regia"). Agli ascoltatori non cambia nulla: il conduttore non si ascolta.
voice_delay = 0.1   # 16/10: 0.6 -> 0.3 -> 0.1 s: la voce entra mentre la musica sta ancora scendendo (richiesta utente)
mic = buffer(id="mic_delay", fallible=true, buffer=voice_delay, max=voice_delay + 1., mic)
# ── Processore voce "come il NowPlaying Hub" (16/10/2026) ───────────────────
# Stesso ordine e stesse impostazioni del NowPlaying Hub (un altro programma dell'autore:
# tone -1, bass 3.5, livella/de-esser/voce piena attivi), fatto
# con i filtri FFmpeg (i filter.iir.* di Liquidsoap 2.2.4 qui non partono):
#  tono -1 semitono -> voce piena (taglio ripido 60 Hz, bassi 160 Hz, corpo
#  250 Hz, -2 dB a 3 kHz) -> riduzione fruscio (< -52 dB) -> livellatore 4:1
#  da -40 dB +15 dB -> de-esser -> limitatore -1 dB.
# Provato isolato (test_clock/voicefx*.liq): tempo reale, nessun ritardo.
# Edizione: tono e voce piena si regolano in Impostazioni -> Microfono.
fx_tone = @@FX_TONE@@     # semitoni: negativo = voce piu' grave (0 = voce naturale)
fx_bass = @@FX_BASS@@     # dB di "voce piena" sotto 160 Hz
def voice_fx(s) =
  def mkfilter(graph) =
    let {audio = a} = source.tracks(s)
    a = ffmpeg.filter.audio.input(graph, a)
    a = if fx_tone != 0. then
          r = 44100. * pow(2., fx_tone / 12.)
          a = ffmpeg.filter.asetrate(graph, a, sample_rate=int_of_float(r))
          a = ffmpeg.filter.aresample(graph, a, sample_rate=44100)
          ffmpeg.filter.atempo(graph, a, tempo=44100. / r)
        else a end
    a = ffmpeg.filter.highpass(graph, a, frequency=60., poles=2)
    a = ffmpeg.filter.highpass(graph, a, frequency=60., poles=2)
    a = ffmpeg.filter.bass(graph, a, frequency=160., gain=fx_bass)
    a = ffmpeg.filter.equalizer(graph, a, frequency=250., width_type=2, width=1., gain=fx_bass * 0.4)
    a = ffmpeg.filter.equalizer(graph, a, frequency=3000., width_type=2, width=1., gain=-2.)
    a = ffmpeg.filter.agate(graph, a, threshold=lin_of_dB(-52.), ratio=2., range=lin_of_dB(-24.),
                            attack=5., release=300.)
    a = ffmpeg.filter.acompressor(graph, a, threshold=lin_of_dB(-40.), ratio=4., attack=10.,
                                  release=250., makeup=lin_of_dB(15.))
    a = ffmpeg.filter.deesser(graph, a, i=0.5, m=0.5, f=0.5)
    a = ffmpeg.filter.alimiter(graph, a, limit=lin_of_dB(-1.), attack=5., release=50.)
    a = ffmpeg.filter.audio.output(graph, a)
    source({audio = a, metadata = track.metadata(a), track_marks = track.track_marks(a)})
  end
  ffmpeg.filter.create(mkfilter)
end
# mksafe: il grafo FFmpeg NON deve mai restare senza audio, altrimenti Liquidsoap
# va in errore ("option is None") e si chiude: 15/10 22:12-22:13 con voice_delay 0.1
# la diretta cadeva ogni ~11 s. Con mksafe un vuoto del mic diventa silenzio.
mic = ffmpeg.raw.decode.audio(voice_fx(ffmpeg.raw.encode.audio(%ffmpeg(%audio.raw), mksafe(mic))))
# Volume voce regolabile dall'app (cursore): dB in piu' sopra al compressore.
# Default +6 dB (16/10: "volume microfono basso"); ricordato in mic_boost.txt.
mic_boost = ref(float_of_string(default=6., string.trim(
  file.exists("#{data_dir}/mic_boost.txt") ? file.contents("#{data_dir}/mic_boost.txt") : "6")))
server.register(namespace="mic", description="Volume voce in dB (senza argomento: legge)", "boost",
  fun (arg) -> begin
    if string.trim(arg) != "" then
      v = float_of_string(default=mic_boost(), string.trim(arg))
      mic_boost := if v < -6. then -6. elsif v > 18. then 18. else v end
      file.write(data=string(mic_boost()), "#{data_dir}/mic_boost.txt")
    end
    string(mic_boost())
  end)
mic = amplify(id="mic_boost", {lin_of_dB(mic_boost())}, mic)
mic = limit(id="mic_limit", threshold=-1., mic)
mic_processed = mic   # voce elaborata: serve alla traccia "_voce" della registrazione

# Ducking: due modalita' (scelta nell'app, ricordata in duck_mode.txt)
#  "regia": mic aperto = musica giu' (dissolvenza 0.15 s), mic chiuso = musica su
#           (1 s) appena l'ultima parola e' andata in onda. Come un fader.
#  "auto" : la musica scende quando si parla davvero (> -38 dB) e risale 0.6 s
#           dopo l'ultima parola andata in onda (dissolvenza 1 s).
# Grazie a voice_delay in entrambe la musica e' gia' al 20% quando arriva la
# voce. Provato isolato (test_clock/duck.liq): musica al 20% all'inizio voce.
# Spegnendo, il mic resta aperto voice_delay + 0.4 s: la frase non si taglia.
duck_mode = ref(string.trim(file.exists("#{data_dir}/duck_mode.txt")
  ? file.contents("#{data_dir}/duck_mode.txt") : "auto"))   # edizione: di base musica giu' solo quando si parla
server.register(namespace="mic", description="Modalita' ducking: regia | auto (senza argomento: legge)", "mode",
  fun (arg) -> begin
    a = string.trim(arg)
    if a == "regia" or a == "auto" then
      duck_mode := a
      file.write(data=a, "#{data_dir}/duck_mode.txt")
    end
    duck_mode()
  end)
# ── Pulsanti jingle ("cart", 16/10/2026) ───────────────────────────────────
# Coda separata: il jingle parte subito, SOPRA il programma, e mentre suona la
# musica si abbassa come per la voce. Comandi: cart.push <file>, cart.flush_and_skip.
cart = request.queue(id="cart")
cart = mksafe(cart)                       # silenzio quando non suona: rms affidabile
cart = rms(id="cart_level", duration=0.2, cart)
cart_level = cart
def cart_playing() = cart_level.rms() > lin_of_dB(-70.) end

voice_threshold = lin_of_dB(-38.)
auto_hold = voice_delay + 0.6
mic_tail = voice_delay + 0.4
last_voice = ref(-100.)
mic_off_at = ref(-100.)
mic_was_on = ref(false)
duck_gain = ref(1.)
mic_gain = ref(0.)
# Controllo ogni 0.02 s (era 0.05): in Regia la voce si apre prima (16/10)
duck_tick = 0.02
thread.run(every=duck_tick, fun () -> begin
  now = time()
  if mic_was_on() and not mic_on() then mic_off_at := now end
  mic_was_on := mic_on()
  is_open = mic_on() or now - mic_off_at() < mic_tail
  if mic_on() and mic_level.rms() > voice_threshold then last_voice := now end
  down = cart_playing() or (if duck_mode() == "auto" then
           now - last_voice() < auto_hold
         else
           mic_on() or now - mic_off_at() < voice_delay
         end)
  target = if down then 0.2 else 1. end
  # rampe lineari: giu' in 0.15 s, su in 1 s
  step = if target < duck_gain() then 0.8 / (0.15 / duck_tick) else 0.8 / (1.0 / duck_tick) end   # giu' 0.15 s (era 0.4: dissolvenza troppo lunga)
  duck_gain := if duck_gain() > target then max(target, duck_gain() - step)
               else min(target, duck_gain() + step) end
  # Voce: si apre DI COLPO (in Regia la dissolvenza d'entrata mangiava la prima
  # sillaba, 16/10); si chiude morbida in ~0.1 s.
  mt = if is_open then 1. else 0. end
  mic_gain := if mt > mic_gain() then mt else mic_gain() + (mt - mic_gain()) * 0.2 end
end)

# Livello voce nel log ogni 2 s a mic aperto (serve a regolare soglia e volume)
thread.run(every=2., fun () ->
  if mic_on() then
    log("MIC: #{if duck_mode() == 'auto' then 'Auto (musica giu quando parli)' else 'Regia (musica giu col mic acceso)' end}, livello voce #{int(dB_of_lin(mic_level.rms()))} dB (soglia -38), musica #{int(duck_gain() * 100.)}%, volume voce +#{mic_boost()} dB")
  end)
server.register(namespace="mic", description="Livello voce attuale (dB)", "level",
  fun (_) -> string(dB_of_lin(mic_level.rms())))

radio = amplify(id="music_duck", {duck_gain()}, radio)
radio = add(id="music_plus_cart", normalize=false, [radio, cart])   # jingle sopra la musica (anche in cuffia)

# ── Ascolto in cuffia SOLO MUSICA (senza voce) per il conduttore ───────────
# Va al ricevitore del server Python (mount music.mp3), che lo passa al
# pulsante "🎧 Musica" dell'app; si sente anche il ducking quando si parla.
output.icecast(
  id="music_monitor",
  host="127.0.0.1", port=monitor_port, password="monitor",
  mount="music.mp3", name="Catorweb Musica", public=false,
  %ffmpeg(format="mp3", %audio(codec="libmp3lame", b="128k", ar=44100, channels=2)),
  radio
)

mic = amplify(id="mic_fader", {mic_gain()}, mic)
radio = add(id="music_plus_mic", normalize=false, [radio, mic])
# Limitatore finale (15/10): musica + voce superavano lo 0 dB di ~0.7-0.9 dB
radio = limit(id="final_limit", threshold=-1., radio)

# ── Rilevamento silenzio ───────────────────────────────────────────────────
def on_silence_start() =
  log("SILENCE: rilevato silenzio prolungato")
  file.write(data="on", "#{data_dir}/silence_flag.txt")
end

def on_silence_end() =
  log("SILENCE: fine silenzio")
  file.write(data="off", "#{data_dir}/silence_flag.txt")
end

radio = blank.detect(
  id="silence_detect",
  max_blank=15.,
  min_noise=1.,
  on_noise=on_silence_end,
  track_sensitive=false,
  on_silence_start,
  radio
)

# ── Registrazione (⏺ REC) ─────────────────────────────────────────────────
# Registra esattamente quello che va al VPS (musica + voce) in MP3 192k.
# Comandi: rec.start / rec.stop / rec.status. Ogni avvio = un file nuovo
# Catorweb_AAAA-MM-GG_hh-mm-ss.mp3. In 2.2.4 output.file non ha start/stop via
# telnet: la registrazione riceve audio solo con REC acceso (switch), e quando
# si spegne il file viene chiuso. "Registra ogni diretta": rec_auto.txt = on.
rec_dir = string.replace(pattern="\\\\", fun (_) -> "/", argv(default="registrazioni", 7))
def two(n) = if n < 10 then "0#{n}" else "#{n}" end end
def rec_name() =
  t = time.local()
  "#{rec_dir}/@@REC_PREFIX@@_#{t.year}-#{two(t.month)}-#{two(t.day)}_#{two(t.hour)}-#{two(t.min)}-#{two(t.sec)}.mp3"
end
rec_on = ref(false)
rec_file = ref("")
def rec_set(v) =
  if v and not rec_on() then rec_file := rec_name() end
  rec_on := v
  file.write(data=(if v then rec_file() else "off" end), "#{data_dir}/rec_status.txt")
end
rec_set(false)
server.register(namespace="rec", description="Avvia la registrazione", "start",
                fun (_) -> begin rec_set(true); rec_file() end)
server.register(namespace="rec", description="Ferma la registrazione", "stop",
                fun (_) -> begin rec_set(false); "off" end)
server.register(namespace="rec", description="File in registrazione o off", "status",
                fun (_) -> if rec_on() then rec_file() else "off" end)
output.file(id="recorder", fallible=true,
  on_start=fun () -> log("REC: avviata #{rec_file()}"),
  on_close=fun (f) -> log("REC: chiusa #{f}"),
  %ffmpeg(format="mp3", %audio(codec="libmp3lame", b="192k", ar=44100, channels=2)),
  {rec_file()}, switch(id="rec_gate", track_sensitive=false, [({rec_on()}, radio)]))
# Traccia separata della SOLA VOCE (…_voce.mp3), registrata insieme alla
# principale: utile per il montaggio e per verificare se la voce ha buchi
# (un'interruzione dell'ingresso del mic qui diventa silenzio assoluto).
output.file(id="recorder_voice", fallible=true,
  %ffmpeg(format="mp3", %audio(codec="libmp3lame", b="128k", ar=44100, channels=2)),
  {string.replace(pattern="\\.mp3$", fun (_) -> "_voce.mp3", rec_file())},
  switch(id="rec_voice_gate", track_sensitive=false, [({rec_on()}, mksafe(mic_processed))]))

# "Registra ogni diretta": nell'edizione la avvia il server Python quando accende
# l'uscita verso il server (in 🎧 Prova non si registra da sola).

# ── Output verso il server di streaming ─────────────────────────────────────
# id "stream_out" (uscita verso il server di streaming). Lo skip e' "music.skip":
# NON usare "stream_out.skip", manda in loop il grafo FFmpeg della voce.
# Icecast / harbor: output.icecast; Shoutcast: output.shoutcast (si collega alla porta + 1).
# Il blocco qui sotto lo scrive il server Python (_liq_render) in base al tipo scelto.
# L'uscita parte CHIUSA: "Vai in onda" apre il cancello out_gate (telnet uscita.start),
# cosi' da 🎧 Prova (radio che suona solo sul PC) si va in onda senza fermare la musica.
# (In Liquidsoap 2.2 output.icecast non ha comandi start/stop via telnet.)
out_on = ref(false)
server.register(namespace="uscita", description="Accende l'uscita verso il server", "start",
  fun (_) -> begin out_on := true; file.write(data="", "#{data_dir}/server_error.txt"); log("SERVER: uscita accesa"); "on" end)
server.register(namespace="uscita", description="Spegne l'uscita verso il server", "stop",
  fun (_) -> begin out_on := false; log("SERVER: uscita spenta"); "off" end)
server.register(namespace="uscita", description="on|off", "status",
  fun (_) -> if out_on() then "on" else "off" end)
out_src = switch(id="out_gate", track_sensitive=false, [({out_on()}, radio)])

# Titolo mandato al server: "<secondi> <titolo>" in title_sent.txt. Il server Python guarda
# se subito dopo nel log c'e' "Metadata update may have failed" (il motore non scrive niente
# quando il server accetta) e mostra in Dashboard "titolo inviato ✓ / rifiutato ✗".
def title_sent(np) =
  file.write(data="#{time()} #{np}", "#{data_dir}/title_sent.txt")
end
# Al ricollegamento (connessione caduta, server riavviato) Liquidsoap NON rimanda il titolo
# del brano in corso: il server restava senza titolo fino al brano dopo (22/10, provato con
# Icecast e il server finto). Si tengono gli ultimi metadati e li si reinserisce a ogni collegamento.
last_meta = ref([])
out_meta = insert_metadata(id="out_meta", out_src)
out_src = source.on_metadata(out_meta, fun (m) -> begin last_meta := m; title_sent(np_text(m)) end)

def on_vps_connect() =
  log("SERVER: collegato a #{vps_host}:#{vps_port}")
  file.write(data="on", "#{data_dir}/harbor_live.txt")
  file.write(data="", "#{data_dir}/server_error.txt")
  if list.length(last_meta()) > 0 then
    out_meta.insert_metadata(last_meta())   # titolo in corso di nuovo al server
  end
end

def on_vps_disconnect() =
  log("SERVER: scollegato da #{vps_host}:#{vps_port}")
  file.write(data="off", "#{data_dir}/harbor_live.txt")
end

def on_vps_error(e) =
  log("SERVER: errore di collegamento: #{e}")
  file.write(data="#{e}", "#{data_dir}/server_error.txt")   # mostrato nell'app
  5.   # riprova dopo 5 secondi
end

@@OUTPUT@@

# ── Ascolto locale (pulsante "🎧 Locale" della dashboard) ──────────────────
# NON output.harbor: su Windows un ascoltatore in pausa bloccava tutto
# Liquidsoap (e quindi la diretta sul VPS). Il monitor va al ricevitore del
# server Python, che legge sempre e non fa mai aspettare Liquidsoap.
output.icecast(
  id="local_monitor",
  host="127.0.0.1", port=monitor_port, password="monitor",
  mount="live.mp3", name="Catorweb Monitor", public=false,
  %ffmpeg(format="mp3", %audio(codec="libmp3lame", b="128k", ar=44100, channels=2)),
  radio
)
