-- "Cómo funciona": a short guide over the sections that need one (Peregrino, 2026-11-12: "no se entiende … ¿habría
-- alguna manera de dárselo más masticado a los usuarios?"). The first time you open such a section the guide
-- shows by itself; after that, the "?" button in the window's header brings it back. Each guide is a few steps
-- in order, each with an example, in plain words.
local _, BG = ...
local UI, C = BG.UI, BG.color

BG.guides = {
  raids = {
    title = "Así funcionan las Raids",
    steps = {
      { icon = "Interface\\Icons\\INV_Misc_Note_01", title = "Crear y apuntarse",
        text = "Cualquiera crea una raid con «Nueva raid». Cada uno se apunta con su rol: «Voy», «Quizá» o «No voy»." },
      { icon = "Interface\\Icons\\INV_Misc_GroupNeedMore", title = "Los grupos",
        text = "«Grupos» enseña los grupos de la banda como en el juego. El líder de la raid, quien la creó y los oficiales arrastran a cada uno a su grupo y su fila (o lo pulsan y luego pulsan dónde va)." },
      { icon = "Interface\\Icons\\INV_Letter_15", title = "Invitar",
        text = "«Invitar confirmados» invita a los que van y están conectados, y convierte el grupo en banda." },
      { icon = "Interface\\Icons\\Ability_Warrior_BattleShout", title = "Colocar en la banda",
        text = "Con la banda ya formada, «Colocar en la banda» mueve a cada uno a su grupo de verdad (el orden dentro del grupo lo pone el juego). Hace falta ser líder o ayudante, y fuera de combate." },
    },
  },
  arena = {
    title = "Así funciona la Arena",
    steps = {
      { icon = "Interface\\Icons\\Ability_DualWield", title = "Un duelo",
        text = "Batíos en duelo desde el juego (clic derecho en su retrato, «Duelo»). Al terminar, el juego dice quién ganó, y el addon de quien pierde lo apunta solo." },
      { icon = "Interface\\Icons\\INV_Misc_Note_02", title = "La puntuación",
        text = "Todos empiezan con 1500. Ganar a alguien mejor da más puntos. Por ejemplo, en tus primeros combates y con el mismo nivel: ganar a uno de 1600 da unos 26; a uno de 1400, unos 14." },
      { icon = "Interface\\Icons\\INV_Misc_Ribbon_01", title = "Rangos y cinturón",
        text = "Con 5 combates tienes rango: Oro, Plata o Bronce. El campeón lleva el cinturón, y quien le gane se lo queda." },
      { icon = "Interface\\Icons\\INV_Letter_15", title = "Retar y mirar",
        text = "En «Retos» retas a quien esté conectado; si acepta, os avisamos. «Cara a cara» pone a dos luchadores frente a frente, con su vida en directo si están cerca. Sin oro." },
      { icon = "Interface\\Icons\\INV_Misc_Trophy_03", title = "Torneos y veladas",
        text = "En «Torneos», cualquiera crea uno. Cada uno se apunta; quien lo dirige sortea con /roll y sale el cuadro. Cada combate lo decide el duelo entre los dos." },
      { icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", title = "La Taberna",
        text = "Huesos: un juego de dados por puntos, contra la casa para practicar o contra alguien de la hermandad. Y una lotería con boletos gratis cada día. Sin oro." },
    },
  },
  pvp = {
    title = "Así funciona «Se busca»",
    steps = {
      { icon = "Interface\\Icons\\Ability_Rogue_FeignDeath", title = "Te matan",
        text = "Si alguien de la otra facción te mata fuera de mazmorras y campos de batalla, tu addon lo apunta solo, con el resumen de muerte del juego. Ese jugador entra en la lista." },
      { icon = "Interface\\Icons\\INV_Misc_Coin_02", title = "Su recompensa",
        text = "Cada miembro que mata le suma 1 de recompensa; 2 si le sacaba 10 niveles o más. Por ejemplo: mata a tres de los vuestros y su recompensa es 3." },
      { icon = "Interface\\Icons\\Ability_Hunter_SniperShot", title = "Cazarle",
        text = "Si le das tú el golpe final, te llevas su recompensa más 1 punto, y su recompensa vuelve a cero. Los puntos de 90 días hacen el ranking de cazadores." },
      { icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath", title = "Cuidado, está cerca",
        text = "Cuando veas a un buscado (en tu objetivo o en su placa de nombre), te avisa y lleva una calavera roja sobre el nombre." },
    },
  },
  rankings = {
    title = "Así funcionan los honores",
    steps = {
      { icon = "Interface\\Icons\\INV_Misc_Ribbon_01", title = "Los rankings",
        text = "A la izquierda, un honor por línea: mejor cazador, campeón de la Arena, mayor donante, mejor artesano, mejor reclutador y fiel a las raids. Pulsa uno y ves sus 10 primeros." },
      { icon = "Interface\\Icons\\INV_Misc_Note_02", title = "De dónde sale",
        text = "Se cuenta con lo que la hermandad ya apunta en BlazonGuild. Encima de cada ranking dice cómo se cuenta." },
      { icon = "Interface\\Icons\\INV_Helmet_06", title = "El honor",
        text = "El primero de cada ranking lleva ese honor: sale en su ficha, con un escudo dorado sobre su nombre en el juego y junto a lo que escribe en el chat." },
      { icon = "Interface\\Icons\\INV_Misc_Gear_01", title = "Las marcas",
        text = "Sobre los miembros de la hermandad sale vuestro escudo. Si no quieres ver las marcas (tampoco las del chat), quítalas abajo o con /bg marcas." },
    },
  },
  recruit = {
    title = "Así funciona el Reclutamiento",
    steps = {
      { icon = "Interface\\Icons\\INV_Misc_Note_02", title = "Vuestra ficha",
        text = "Los oficiales escriben la ficha pública: a qué os dedicáis, idioma, cuándo jugáis y a quién buscáis (por ejemplo, sanadores)." },
      { icon = "Interface\\Icons\\INV_Misc_Spyglass_02", title = "Quien busca hermandad",
        text = "Un jugador sin hermandad abre BlazonGuild, escribe vuestro nombre y ve vuestra ficha. Necesita que alguno de vosotros esté conectado con el addon." },
      { icon = "Interface\\Icons\\INV_Letter_15", title = "Pide entrar",
        text = "Pulsa «Pedir entrar» y a los oficiales conectados les llega la petición. «Invitar» manda la invitación del juego; el addon nunca invita solo." },
      { icon = "Interface\\Icons\\INV_Misc_GroupNeedMore", title = "Quién trae más gente",
        text = "Cada nuevo miembro dice quién le trajo, y sale quién trae más gente a la hermandad." },
    },
  },
  treasury = {
    title = "Así funciona la Tesorería",
    steps = {
      { icon = "Interface\\Icons\\INV_Misc_Coin_01", title = "Los tesoreros",
        text = "El maestro nombra a los tesoreros en «Cuotas». Son quienes guardan el oro de la hermandad. El addon nunca mueve oro: solo lo apunta." },
      { icon = "Interface\\Icons\\INV_Misc_Coin_02", title = "Dar oro",
        text = "Dale oro a un tesorero por comercio o por correo. Su addon lo apunta solo en el libro, y a ti te llega un «gracias»." },
      { icon = "Interface\\Icons\\INV_Misc_Coin_17", title = "La cuota semanal",
        text = "Si el maestro pone cuota (por ejemplo, 5 de oro por semana), en «Resumen» ves cuánto has dado esta semana y cuánto te falta." },
      { icon = "Interface\\Icons\\INV_Misc_Bag_10", title = "Campañas y banco",
        text = "Una campaña junta oro para algo concreto, con su barra de progreso. En «Banco» ves lo que había la última vez que un oficial lo abrió." },
    },
  },
  crafts = {
    title = "Así funciona Artesanía y botín",
    steps = {
      { icon = "Interface\\Icons\\Trade_BlackSmithing", title = "Publica lo que sabes fabricar",
        text = "En el juego, abre la ventana de tu profesión (por ejemplo, Herrería). BlazonGuild te pregunta si quieres que tu hermandad lo vea: di «Publicar»." },
      { icon = "Interface\\Icons\\INV_Misc_Spyglass_02", title = "Busca quién fabrica algo",
        text = "En la pestaña «Quién fabrica qué», escribe el objeto (por ejemplo «poción») y verás quién sabe hacerlo. «Susurrar» abre el chat para hablarle." },
      { icon = "Interface\\Icons\\INV_Crate_04", title = "Haz un encargo",
        text = "En «Encargos», pide el objeto. El artesano pulsa «Lo hago» y luego «Hecho»; cuando lo tengas, pulsa «Recibido». Te avisamos en cada paso." },
      { icon = "Interface\\Icons\\INV_Misc_Bag_10", title = "Botín de las bandas",
        text = "Los oficiales apuntan a quién se dio cada objeto y por qué, para que la próxima banda empiece de lo ya decidido. Sin pujas ni oro." },
    },
  },
  map = {
    title = "Así funciona el Mapa",
    steps = {
      { icon = "Interface\\Icons\\INV_Misc_Map_01", title = "Dónde está tu hermandad",
        text = "A la izquierda ves cuántos compañeros hay conectados en cada zona y quiénes son. No hace falta que tengan el addon." },
      { icon = "Interface\\Icons\\Spell_Holy_MindVision", title = "Compartir tu posición (si quieres)",
        text = "Pulsa «Compartir mi posición»: tus compañeros con BlazonGuild te verán como un punto en su mapa del mundo (tecla M) y en su minimapa. Solo tu hermandad." },
      { icon = "Interface\\Icons\\Ability_Hunter_Pathfinding", title = "Seguir a alguien",
        text = "En la pestaña «En el mapa», «Seguir» pone una flecha bajo el minimapa que te lleva hasta un compañero o hasta el punto de reunión, con los metros que faltan." },
      { icon = "Interface\\Icons\\Spell_Arcane_PortalDalaran", title = "Las capas",
        text = "Una capa es una copia de la zona. Para saber la tuya, haz clic en el juego en dos personajes que no sean jugadores (por ejemplo, dos guardias)." },
      { icon = "Interface\\Icons\\INV_Letter_15", title = "Pasar a la capa de un compañero",
        text = "Pulsa «Pedir invitación» en su capa. Él decide si te invita; al llegar a su capa, el addon te saca del grupo solo." },
      { icon = "Interface\\Icons\\INV_Misc_Spyglass_02", title = "Avistamientos",
        text = "En «Avistamientos» preguntas dónde se vio a un jugador de la otra facción. Responden los compañeros que lo aceptan, con lo que vieron en el último cuarto de hora." },
    },
  },
  alliance = {
    title = "Así funciona la Alianza",
    steps = {
      { icon = "Interface\\Icons\\INV_BannerPVP_02", title = "Varias hermandades amigas",
        text = "Una alianza une tu hermandad con otras: chat común, una pestaña para cada hermandad y salas compartidas. Cada una sigue con su maestro." },
      { icon = "Interface\\Icons\\INV_Letter_15", title = "La deciden los maestros",
        text = "El maestro la crea e invita a alguien de otra hermandad que tenga BlazonGuild. Su maestro la acepta o la rechaza." },
      { icon = "Interface\\Icons\\INV_Crown_01", title = "El líder",
        text = "Cada maestro vota a una hermandad. Lidera la que tenga más de la mitad de los votos; si ninguna, la fundadora." },
      { icon = "Interface\\Icons\\INV_Misc_Note_06", title = "Hablar",
        text = "En la sección Chat aparecen las pestañas de la alianza: «Toda la alianza» y una por cada hermandad hermana." },
      { icon = "Interface\\Icons\\INV_Letter_15", title = "Cartas y avisos",
        text = "La hermandad que lidera escribe cartas a los maestros, dice a qué hermandad van los nuevos y puede ocultar a alguien en los chats comunes. Y en la Sala de guerra, sus operaciones llegan a todas." },
    },
  },
  war = {
    title = "Así funciona la Sala de guerra",
    steps = {
      { icon = "Interface\\Icons\\Ability_Warrior_BattleShout", title = "Escuadras",
        text = "Los oficiales crean escuadras pequeñas con su jefe (por ejemplo «Los Lobos», de asalto). El jefe elige a su gente; la escuadra tiene su propio chat." },
      { icon = "Interface\\Icons\\INV_Misc_Map_01", title = "Operaciones",
        text = "Oficiales y jefes planean una operación: qué, cuándo y dónde, y qué escuadras van. A los llamados les llega un aviso." },
      { icon = "Interface\\Icons\\Ability_DualWield", title = "Responde y acude",
        text = "Pulsa «Voy», «Reserva» o «No puedo». Un cuarto de hora antes te lo recordamos; al empezar, te sale la alerta en pantalla." },
      { icon = "Interface\\Icons\\INV_Misc_Note_02", title = "El parte",
        text = "Al terminar, quien la dirigió escribe cómo fue. Queda en la crónica de la hermandad con quién estuvo." },
    },
  },
}

local function seen()
  BG.db.guidesSeen = BG.db.guidesSeen or {}
  return BG.db.guidesSeen
end

local function stepRow(parent, i)
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(62)
  r.num = UI.Text(r, 18, C.goldTitle, { font = BG.font.display, justify = "CENTER" })
  r.num:SetPoint("TOPLEFT", 0, -6)
  r.num:SetWidth(24)
  r.num:SetText(tostring(i))
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(34, 34)
  r.icon:SetPoint("TOPLEFT", 30, -2)
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.title = UI.Text(r, 14, C.goldTitle, { font = BG.font.display })
  r.title:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 12, 0)
  r.title:SetPoint("RIGHT", 0, 0)
  r.text = UI.Text(r, 12, C.text, { wrap = true })
  r.text:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -4)
  r.text:SetPoint("RIGHT", 0, 0)
  r.text:SetSpacing(2)
  return r
end

local function build(vf)
  local g = CreateFrame("Frame", nil, vf)
  g:SetAllPoints()
  g:SetFrameLevel(vf:GetFrameLevel() + 60)
  g:EnableMouse(true)
  g.shade = g:CreateTexture(nil, "BACKGROUND")
  g.shade:SetAllPoints()
  g.shade:SetColorTexture(0.02, 0.03, 0.05, 0.82)
  g.plate = UI.Plate(g, { corners = 22, rail = 0.32 })
  g.plate:SetPoint("TOPLEFT", 48, -28)
  g.plate:SetPoint("BOTTOMRIGHT", -48, 28)
  g.head = UI.Heading(g.plate, "")
  g.head:SetPoint("TOPLEFT", 24, -16)
  g.head:SetPoint("TOPRIGHT", -24, -16)
  g.rows = {}
  g.ok = UI.Button(g.plate, "Entendido", { primary = true, height = 30, width = 140 })
  g.ok:SetPoint("BOTTOMRIGHT", -24, 18)
  g.ok:SetScript("OnClick", function()
    g:Hide()
  end)
  g.note = UI.Text(g.plate, 11, C.text3, { wrap = true })
  g.note:SetPoint("BOTTOMLEFT", 24, 26)
  g.note:SetPoint("RIGHT", g.ok, "LEFT", -16, 0)
  g.note:SetText("Vuelve a verla cuando quieras con el botón «?» de arriba.")
  g:Hide()
  return g
end

-- Shows the guide of section `key` over its screen.
function BG:ShowGuide(key)
  local def = BG.guides[key]
  local vf = BG.window and BG.window.viewFrames[key]
  if not (def and vf) then
    return false
  end
  vf.guide = vf.guide or build(vf)
  local g = vf.guide
  g.head.title:SetText(def.title)
  local prev = g.head
  for i, s in ipairs(def.steps) do
    local r = g.rows[i] or stepRow(g.plate, i)
    g.rows[i] = r
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", i == 1 and 0 or 0, i == 1 and -12 or -6)
    r:SetPoint("RIGHT", g.plate, "RIGHT", -24, 0)
    r.icon:SetTexture(BG.file(s.icon, "Interface\\Icons\\INV_Misc_QuestionMark"))
    r.title:SetText(s.title)
    r.text:SetText(s.text)
    r:Show()
    prev = r
  end
  for i = #def.steps + 1, #g.rows do
    g.rows[i]:Hide()
  end
  g:Show()
  seen()[key] = true
  return true
end

function BG:HasGuide(key)
  return BG.guides[key] ~= nil
end

-- The first time a section with a guide opens, its guide shows by itself.
function BG:MaybeGuide(key)
  if BG.guides[key] and not seen()[key] then
    BG:ShowGuide(key)
  end
end
