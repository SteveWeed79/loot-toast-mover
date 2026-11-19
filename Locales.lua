----------------------------------------------------------------------------------------------------
-- LootToastMover translations. Loaded before LootToastMover.lua, which reads them as ns.L.
----------------------------------------------------------------------------------------------------
-- English is the source of every string. Each other language replaces what it translates, and
-- anything it leaves out falls back to English rather than showing nothing.
--
-- The translations here are drafts. Translators can improve them on CurseForge, and a packaged
-- release swaps their work in over the drafts (see the end of this file). The English is
-- uploaded to CurseForge from here as part of every release, so this file stays the source of
-- what there is to translate.
--
-- When translating:
--   * Keep every %s. The code fills them in, so each language needs the same number of them.
--   * Keep slash commands (/ltm, /ltm test, /ltm reset, /loottoastpos) exactly as they are.
--     They are typed in English in every client.
--   * ANCHOR_DRAG and ANCHOR_LANDS are the two lines on a box the size of a loot toast, so
--     keep each one short. No string contains a line break, which keeps them safe to send
--     through CurseForge's translation tool.
--   * Chat messages follow a "[LootToastMover]" prefix, so they can read as a fragment.
local _, ns = ...

local enUS = {
    -- The anchor box itself.
    ANCHOR_DRAG = "Drag me.",
    ANCHOR_LANDS = "Toasts appear in this exact space.",

    -- Tooltip on the minimap button, the broker plugin and the Addon Compartment.
    TOOLTIP_CLICK = "Click to show or hide the anchor box",
    TOOLTIP_RIGHT_CLICK = "Right-click for options",
    TOOLTIP_TEST = "show a sample toast",
    TOOLTIP_RESET = "reset position",

    -- Options panel, under Game Menu → Options → AddOns.
    PANEL_INTRO = "Show the anchor box, drag it where you want loot toasts to appear, then hide it again. Toasts land in exactly that space and stack upward from it.",
    BUTTON_TOGGLE = "Show / hide anchor box",
    BUTTON_TEST = "Show a sample toast",
    BUTTON_RESET = "Reset position",
    CHECK_MINIMAP = "Show the minimap button",
    CHECK_STACK_DOWN = "Stack new toasts downward",

    -- What each slash command does, listed in the options panel and in /ltm's usage message.
    EITHER_COMMAND = "%s or %s",
    COMMAND_TOGGLE = "show or hide the anchor box",
    COMMAND_TEST = "show a sample loot toast",
    COMMAND_RESET = "move the anchor back to its default position",
    COMMAND_CONFIG = "open the options panel",
    COMMAND_CONFIG_HERE = "open this panel",
    COMMAND_MINIMAP = "show or hide the minimap button",

    -- Chat messages.
    USAGE = "usage:",
    POSITION_RESET = "position reset.",
    MINIMAP_SHOWN = "minimap button shown.",
    MINIMAP_HIDDEN = "minimap button hidden.",
    NO_ALERT_SYSTEM = "the loot alert system is not available yet.",
    NO_OPTIONS = "the options panel is not available on this client. %s",
    OPTIONS_FAILED = "could not open the options panel. %s",
    USE_COMMANDS = "Use /ltm, /ltm test and /ltm reset instead.",
    ANCHOR_SHOWN = "anchor box shown. Drag it, then press Escape or type /ltm to hide it.",

    -- Shown if the addon itself goes wrong. %s is the error text, then the number of errors.
    ERROR_ONCE = "hit an error and is carrying on: %s",
    STOOD_DOWN = "stopped after %s errors. Type /reload to start it again.",
}

local translations = {
    deDE = {
        ANCHOR_DRAG = "Zum Verschieben ziehen.",
        ANCHOR_LANDS = "Meldungen erscheinen genau hier.",
        TOOLTIP_CLICK = "Klicken, um den Ankerrahmen ein- oder auszublenden",
        TOOLTIP_RIGHT_CLICK = "Rechtsklick für Optionen",
        TOOLTIP_TEST = "Beispielmeldung anzeigen",
        TOOLTIP_RESET = "Position zurücksetzen",
        PANEL_INTRO = "Den Ankerrahmen einblenden, an die Stelle ziehen, an der Beutemeldungen erscheinen sollen, und wieder ausblenden. Meldungen erscheinen genau dort und stapeln sich von dort nach oben.",
        BUTTON_TOGGLE = "Ankerrahmen ein-/ausblenden",
        BUTTON_TEST = "Beispielmeldung anzeigen",
        BUTTON_RESET = "Position zurücksetzen",
        CHECK_MINIMAP = "Minikartensymbol anzeigen",
        CHECK_STACK_DOWN = "Neue Meldungen nach unten stapeln",
        EITHER_COMMAND = "%s oder %s",
        COMMAND_TOGGLE = "Ankerrahmen ein- oder ausblenden",
        COMMAND_TEST = "Beispiel-Beutemeldung anzeigen",
        COMMAND_RESET = "Anker auf die Standardposition zurücksetzen",
        COMMAND_CONFIG = "Optionsfenster öffnen",
        COMMAND_CONFIG_HERE = "dieses Fenster öffnen",
        COMMAND_MINIMAP = "Minikartensymbol ein- oder ausblenden",
        USAGE = "Verwendung:",
        POSITION_RESET = "Position zurückgesetzt.",
        MINIMAP_SHOWN = "Minikartensymbol eingeblendet.",
        MINIMAP_HIDDEN = "Minikartensymbol ausgeblendet.",
        NO_ALERT_SYSTEM = "Das Beutemeldungssystem ist noch nicht verfügbar.",
        NO_OPTIONS = "Das Optionsfenster ist in diesem Client nicht verfügbar. %s",
        OPTIONS_FAILED = "Das Optionsfenster konnte nicht geöffnet werden. %s",
        USE_COMMANDS = "Stattdessen /ltm, /ltm test und /ltm reset verwenden.",
        ANCHOR_SHOWN = "Ankerrahmen eingeblendet. Verschieben, dann Escape drücken oder /ltm eingeben, um ihn auszublenden.",
        ERROR_ONCE = "hat einen Fehler festgestellt und läuft weiter: %s",
        STOOD_DOWN = "nach %s Fehlern angehalten. /reload eingeben, um es wieder zu starten.",
    },

    esES = {
        ANCHOR_DRAG = "Arrástrame.",
        ANCHOR_LANDS = "Las alertas aparecen justo en este espacio.",
        TOOLTIP_CLICK = "Haz clic para mostrar u ocultar el marco de anclaje",
        TOOLTIP_RIGHT_CLICK = "Clic derecho para las opciones",
        TOOLTIP_TEST = "mostrar una alerta de ejemplo",
        TOOLTIP_RESET = "restablecer la posición",
        PANEL_INTRO = "Muestra el marco de anclaje, arrástralo hasta donde quieras que aparezcan las alertas de botín y vuelve a ocultarlo. Las alertas aparecen justo en ese espacio y se apilan hacia arriba.",
        BUTTON_TOGGLE = "Mostrar/ocultar marco de anclaje",
        BUTTON_TEST = "Mostrar una alerta de ejemplo",
        BUTTON_RESET = "Restablecer posición",
        CHECK_MINIMAP = "Mostrar el botón del minimapa",
        CHECK_STACK_DOWN = "Apilar las alertas nuevas hacia abajo",
        EITHER_COMMAND = "%s o %s",
        COMMAND_TOGGLE = "mostrar u ocultar el marco de anclaje",
        COMMAND_TEST = "mostrar una alerta de botín de ejemplo",
        COMMAND_RESET = "devolver el ancla a su posición predeterminada",
        COMMAND_CONFIG = "abrir el panel de opciones",
        COMMAND_CONFIG_HERE = "abrir este panel",
        COMMAND_MINIMAP = "mostrar u ocultar el botón del minimapa",
        USAGE = "uso:",
        POSITION_RESET = "posición restablecida.",
        MINIMAP_SHOWN = "botón del minimapa visible.",
        MINIMAP_HIDDEN = "botón del minimapa oculto.",
        NO_ALERT_SYSTEM = "el sistema de alertas de botín aún no está disponible.",
        NO_OPTIONS = "el panel de opciones no está disponible en este cliente. %s",
        OPTIONS_FAILED = "no se pudo abrir el panel de opciones. %s",
        USE_COMMANDS = "Usa /ltm, /ltm test y /ltm reset en su lugar.",
        ANCHOR_SHOWN = "marco de anclaje visible. Arrástralo y luego pulsa Escape o escribe /ltm para ocultarlo.",
        ERROR_ONCE = "ha encontrado un error y sigue funcionando: %s",
        STOOD_DOWN = "detenido tras %s errores. Escribe /reload para volver a iniciarlo.",
    },

    frFR = {
        ANCHOR_DRAG = "Faites-moi glisser.",
        ANCHOR_LANDS = "Les alertes apparaissent exactement ici.",
        TOOLTIP_CLICK = "Cliquez pour afficher ou masquer le cadre d'ancrage",
        TOOLTIP_RIGHT_CLICK = "Clic droit pour les options",
        TOOLTIP_TEST = "afficher une alerte d'exemple",
        TOOLTIP_RESET = "réinitialiser la position",
        PANEL_INTRO = "Affichez le cadre d'ancrage, faites-le glisser là où vous voulez voir apparaître les alertes de butin, puis masquez-le à nouveau. Les alertes apparaissent exactement à cet endroit et s'empilent vers le haut.",
        BUTTON_TOGGLE = "Afficher/masquer le cadre d'ancrage",
        BUTTON_TEST = "Afficher une alerte d'exemple",
        BUTTON_RESET = "Réinitialiser la position",
        CHECK_MINIMAP = "Afficher le bouton de la minicarte",
        CHECK_STACK_DOWN = "Empiler les nouvelles alertes vers le bas",
        EITHER_COMMAND = "%s ou %s",
        COMMAND_TOGGLE = "afficher ou masquer le cadre d'ancrage",
        COMMAND_TEST = "afficher une alerte de butin d'exemple",
        COMMAND_RESET = "remettre l'ancre à sa position par défaut",
        COMMAND_CONFIG = "ouvrir le panneau d'options",
        COMMAND_CONFIG_HERE = "ouvrir ce panneau",
        COMMAND_MINIMAP = "afficher ou masquer le bouton de la minicarte",
        USAGE = "utilisation :",
        POSITION_RESET = "position réinitialisée.",
        MINIMAP_SHOWN = "bouton de la minicarte affiché.",
        MINIMAP_HIDDEN = "bouton de la minicarte masqué.",
        NO_ALERT_SYSTEM = "le système d'alertes de butin n'est pas encore disponible.",
        NO_OPTIONS = "le panneau d'options n'est pas disponible sur ce client. %s",
        OPTIONS_FAILED = "impossible d'ouvrir le panneau d'options. %s",
        USE_COMMANDS = "Utilisez plutôt /ltm, /ltm test et /ltm reset.",
        ANCHOR_SHOWN = "cadre d'ancrage affiché. Faites-le glisser, puis appuyez sur Échap ou tapez /ltm pour le masquer.",
        ERROR_ONCE = "a rencontré une erreur et continue : %s",
        STOOD_DOWN = "arrêté après %s erreurs. Tapez /reload pour le relancer.",
    },

    itIT = {
        ANCHOR_DRAG = "Trascinami.",
        ANCHOR_LANDS = "Gli avvisi appaiono esattamente in questo punto.",
        TOOLTIP_CLICK = "Clicca per mostrare o nascondere il riquadro di ancoraggio",
        TOOLTIP_RIGHT_CLICK = "Clic destro per le opzioni",
        TOOLTIP_TEST = "mostra un avviso di esempio",
        TOOLTIP_RESET = "ripristina la posizione",
        PANEL_INTRO = "Mostra il riquadro di ancoraggio, trascinalo dove vuoi che compaiano gli avvisi di bottino, poi nascondilo di nuovo. Gli avvisi appaiono esattamente in quel punto e si impilano verso l'alto.",
        BUTTON_TOGGLE = "Mostra/nascondi riquadro di ancoraggio",
        BUTTON_TEST = "Mostra un avviso di esempio",
        BUTTON_RESET = "Ripristina posizione",
        CHECK_MINIMAP = "Mostra il pulsante della minimappa",
        CHECK_STACK_DOWN = "Impila i nuovi avvisi verso il basso",
        EITHER_COMMAND = "%s o %s",
        COMMAND_TOGGLE = "mostra o nascondi il riquadro di ancoraggio",
        COMMAND_TEST = "mostra un avviso di bottino di esempio",
        COMMAND_RESET = "riporta l'ancoraggio alla posizione predefinita",
        COMMAND_CONFIG = "apri il pannello delle opzioni",
        COMMAND_CONFIG_HERE = "apri questo pannello",
        COMMAND_MINIMAP = "mostra o nascondi il pulsante della minimappa",
        USAGE = "uso:",
        POSITION_RESET = "posizione ripristinata.",
        MINIMAP_SHOWN = "pulsante della minimappa mostrato.",
        MINIMAP_HIDDEN = "pulsante della minimappa nascosto.",
        NO_ALERT_SYSTEM = "il sistema degli avvisi di bottino non è ancora disponibile.",
        NO_OPTIONS = "il pannello delle opzioni non è disponibile su questo client. %s",
        OPTIONS_FAILED = "impossibile aprire il pannello delle opzioni. %s",
        USE_COMMANDS = "Usa invece /ltm, /ltm test e /ltm reset.",
        ANCHOR_SHOWN = "riquadro di ancoraggio visibile. Trascinalo, poi premi Esc o digita /ltm per nasconderlo.",
        ERROR_ONCE = "ha riscontrato un errore e continua a funzionare: %s",
        STOOD_DOWN = "arrestato dopo %s errori. Digita /reload per riavviarlo.",
    },

    koKR = {
        ANCHOR_DRAG = "끌어서 옮기세요.",
        ANCHOR_LANDS = "알림이 정확히 이 자리에 나타납니다.",
        TOOLTIP_CLICK = "클릭하여 앵커 상자 표시/숨기기",
        TOOLTIP_RIGHT_CLICK = "오른쪽 클릭하여 설정 열기",
        TOOLTIP_TEST = "예시 알림 표시",
        TOOLTIP_RESET = "위치 초기화",
        PANEL_INTRO = "앵커 상자를 표시하고 전리품 알림이 나타날 위치로 끌어 놓은 다음 다시 숨기세요. 알림은 정확히 그 자리에 나타나며 위쪽으로 쌓입니다.",
        BUTTON_TOGGLE = "앵커 상자 표시/숨기기",
        BUTTON_TEST = "예시 알림 표시",
        BUTTON_RESET = "위치 초기화",
        CHECK_MINIMAP = "미니맵 버튼 표시",
        CHECK_STACK_DOWN = "새 알림을 아래쪽으로 쌓기",
        EITHER_COMMAND = "%s 또는 %s",
        COMMAND_TOGGLE = "앵커 상자 표시/숨기기",
        COMMAND_TEST = "예시 전리품 알림 표시",
        COMMAND_RESET = "앵커를 기본 위치로 되돌리기",
        COMMAND_CONFIG = "설정 창 열기",
        COMMAND_CONFIG_HERE = "이 창 열기",
        COMMAND_MINIMAP = "미니맵 버튼 표시/숨기기",
        USAGE = "사용법:",
        POSITION_RESET = "위치를 초기화했습니다.",
        MINIMAP_SHOWN = "미니맵 버튼을 표시했습니다.",
        MINIMAP_HIDDEN = "미니맵 버튼을 숨겼습니다.",
        NO_ALERT_SYSTEM = "전리품 알림 시스템을 아직 사용할 수 없습니다.",
        NO_OPTIONS = "이 클라이언트에서는 설정 창을 사용할 수 없습니다. %s",
        OPTIONS_FAILED = "설정 창을 열 수 없습니다. %s",
        USE_COMMANDS = "대신 /ltm, /ltm test, /ltm reset 명령어를 사용하세요.",
        ANCHOR_SHOWN = "고정 상자를 표시했습니다. 끌어서 옮긴 뒤 Esc 키를 누르거나 /ltm 을 입력하면 숨겨집니다.",
        ERROR_ONCE = "오류가 발생했지만 계속 동작합니다: %s",
        STOOD_DOWN = "오류가 %s번 발생해 중지했습니다. 다시 시작하려면 /reload 를 입력하세요.",
    },

    ptBR = {
        ANCHOR_DRAG = "Arraste-me.",
        ANCHOR_LANDS = "Os alertas aparecem exatamente neste espaço.",
        TOOLTIP_CLICK = "Clique para mostrar ou ocultar a caixa de ancoragem",
        TOOLTIP_RIGHT_CLICK = "Clique com o botão direito para as opções",
        TOOLTIP_TEST = "mostrar um alerta de exemplo",
        TOOLTIP_RESET = "redefinir a posição",
        PANEL_INTRO = "Mostre a caixa de ancoragem, arraste-a até onde você quer que os alertas de saque apareçam e oculte-a novamente. Os alertas aparecem exatamente nesse espaço e se empilham para cima.",
        BUTTON_TOGGLE = "Mostrar/ocultar caixa de ancoragem",
        BUTTON_TEST = "Mostrar um alerta de exemplo",
        BUTTON_RESET = "Redefinir posição",
        CHECK_MINIMAP = "Mostrar o botão do minimapa",
        CHECK_STACK_DOWN = "Empilhar os novos alertas para baixo",
        EITHER_COMMAND = "%s ou %s",
        COMMAND_TOGGLE = "mostrar ou ocultar a caixa de ancoragem",
        COMMAND_TEST = "mostrar um alerta de saque de exemplo",
        COMMAND_RESET = "levar a âncora de volta à posição padrão",
        COMMAND_CONFIG = "abrir o painel de opções",
        COMMAND_CONFIG_HERE = "abrir este painel",
        COMMAND_MINIMAP = "mostrar ou ocultar o botão do minimapa",
        USAGE = "uso:",
        POSITION_RESET = "posição redefinida.",
        MINIMAP_SHOWN = "botão do minimapa visível.",
        MINIMAP_HIDDEN = "botão do minimapa oculto.",
        NO_ALERT_SYSTEM = "o sistema de alertas de saque ainda não está disponível.",
        NO_OPTIONS = "o painel de opções não está disponível neste cliente. %s",
        OPTIONS_FAILED = "não foi possível abrir o painel de opções. %s",
        USE_COMMANDS = "Em vez disso, use /ltm, /ltm test e /ltm reset.",
        ANCHOR_SHOWN = "caixa de âncora exibida. Arraste-a e depois pressione Esc ou digite /ltm para ocultá-la.",
        ERROR_ONCE = "encontrou um erro e continua funcionando: %s",
        STOOD_DOWN = "parou após %s erros. Digite /reload para iniciá-lo de novo.",
    },

    ruRU = {
        ANCHOR_DRAG = "Перетащите меня.",
        ANCHOR_LANDS = "Уведомления появятся именно здесь.",
        TOOLTIP_CLICK = "Щелкните, чтобы показать или скрыть рамку привязки",
        TOOLTIP_RIGHT_CLICK = "Правый щелчок: настройки",
        TOOLTIP_TEST = "показать пример уведомления",
        TOOLTIP_RESET = "сбросить позицию",
        PANEL_INTRO = "Покажите рамку привязки, перетащите её туда, где должны появляться уведомления о добыче, и снова скройте. Уведомления появляются точно на этом месте и складываются стопкой вверх.",
        BUTTON_TOGGLE = "Показать/скрыть рамку привязки",
        BUTTON_TEST = "Показать пример уведомления",
        BUTTON_RESET = "Сбросить позицию",
        CHECK_MINIMAP = "Показывать кнопку у миникарты",
        CHECK_STACK_DOWN = "Размещать новые уведомления вниз",
        EITHER_COMMAND = "%s или %s",
        COMMAND_TOGGLE = "показать или скрыть рамку привязки",
        COMMAND_TEST = "показать пример уведомления о добыче",
        COMMAND_RESET = "вернуть рамку в исходное положение",
        COMMAND_CONFIG = "открыть панель настроек",
        COMMAND_CONFIG_HERE = "открыть эту панель",
        COMMAND_MINIMAP = "показать или скрыть кнопку у миникарты",
        USAGE = "использование:",
        POSITION_RESET = "позиция сброшена.",
        MINIMAP_SHOWN = "кнопка у миникарты показана.",
        MINIMAP_HIDDEN = "кнопка у миникарты скрыта.",
        NO_ALERT_SYSTEM = "система уведомлений о добыче ещё недоступна.",
        NO_OPTIONS = "панель настроек недоступна в этом клиенте. %s",
        OPTIONS_FAILED = "не удалось открыть панель настроек. %s",
        USE_COMMANDS = "Используйте вместо этого /ltm, /ltm test и /ltm reset.",
        ANCHOR_SHOWN = "якорь показан. Перетащите его, затем нажмите Escape или введите /ltm, чтобы скрыть.",
        ERROR_ONCE = "произошла ошибка, работа продолжается: %s",
        STOOD_DOWN = "остановлен после %s ошибок. Введите /reload, чтобы запустить снова.",
    },

    zhCN = {
        ANCHOR_DRAG = "拖动我来调整位置。",
        ANCHOR_LANDS = "提示会准确地显示在这里。",
        TOOLTIP_CLICK = "点击显示或隐藏锚点框",
        TOOLTIP_RIGHT_CLICK = "右键点击打开设置",
        TOOLTIP_TEST = "显示示例提示",
        TOOLTIP_RESET = "重置位置",
        PANEL_INTRO = "显示锚点框，把它拖到你希望战利品提示出现的位置，然后再次隐藏。提示会准确地显示在该位置，并向上堆叠。",
        BUTTON_TOGGLE = "显示/隐藏锚点框",
        BUTTON_TEST = "显示示例提示",
        BUTTON_RESET = "重置位置",
        CHECK_MINIMAP = "显示小地图按钮",
        CHECK_STACK_DOWN = "新提示向下堆叠",
        EITHER_COMMAND = "%s 或 %s",
        COMMAND_TOGGLE = "显示或隐藏锚点框",
        COMMAND_TEST = "显示一个示例战利品提示",
        COMMAND_RESET = "将锚点恢复到默认位置",
        COMMAND_CONFIG = "打开设置面板",
        COMMAND_CONFIG_HERE = "打开此面板",
        COMMAND_MINIMAP = "显示或隐藏小地图按钮",
        USAGE = "用法：",
        POSITION_RESET = "位置已重置。",
        MINIMAP_SHOWN = "小地图按钮已显示。",
        MINIMAP_HIDDEN = "小地图按钮已隐藏。",
        NO_ALERT_SYSTEM = "战利品提示系统尚不可用。",
        NO_OPTIONS = "此客户端无法使用设置面板。%s",
        OPTIONS_FAILED = "无法打开设置面板。%s",
        USE_COMMANDS = "请改用 /ltm、/ltm test 和 /ltm reset。",
        ANCHOR_SHOWN = "锚点框已显示。拖动它，然后按 Esc 键或输入 /ltm 将其隐藏。",
        ERROR_ONCE = "遇到一个错误，仍在继续运行：%s",
        STOOD_DOWN = "出现 %s 个错误后已停止。输入 /reload 可重新启动。",
    },

    zhTW = {
        ANCHOR_DRAG = "拖曳我來調整位置。",
        ANCHOR_LANDS = "提示會準確地顯示在這裡。",
        TOOLTIP_CLICK = "點擊顯示或隱藏錨點框",
        TOOLTIP_RIGHT_CLICK = "右鍵點擊開啟設定",
        TOOLTIP_TEST = "顯示範例提示",
        TOOLTIP_RESET = "重置位置",
        PANEL_INTRO = "顯示錨點框，把它拖曳到你希望戰利品提示出現的位置，然後再次隱藏。提示會準確地顯示在該位置，並向上堆疊。",
        BUTTON_TOGGLE = "顯示/隱藏錨點框",
        BUTTON_TEST = "顯示範例提示",
        BUTTON_RESET = "重置位置",
        CHECK_MINIMAP = "顯示小地圖按鈕",
        CHECK_STACK_DOWN = "新提示向下堆疊",
        EITHER_COMMAND = "%s 或 %s",
        COMMAND_TOGGLE = "顯示或隱藏錨點框",
        COMMAND_TEST = "顯示一個範例戰利品提示",
        COMMAND_RESET = "將錨點恢復到預設位置",
        COMMAND_CONFIG = "開啟設定面板",
        COMMAND_CONFIG_HERE = "開啟此面板",
        COMMAND_MINIMAP = "顯示或隱藏小地圖按鈕",
        USAGE = "用法：",
        POSITION_RESET = "位置已重置。",
        MINIMAP_SHOWN = "小地圖按鈕已顯示。",
        MINIMAP_HIDDEN = "小地圖按鈕已隱藏。",
        NO_ALERT_SYSTEM = "戰利品提示系統尚無法使用。",
        NO_OPTIONS = "此用戶端無法使用設定面板。%s",
        OPTIONS_FAILED = "無法開啟設定面板。%s",
        USE_COMMANDS = "請改用 /ltm、/ltm test 和 /ltm reset。",
        ANCHOR_SHOWN = "錨點框已顯示。拖曳它，然後按 Esc 鍵或輸入 /ltm 將其隱藏。",
        ERROR_ONCE = "遇到一個錯誤，仍在繼續執行：%s",
        STOOD_DOWN = "出現 %s 個錯誤後已停止。輸入 /reload 可重新啟動。",
    },
}

-- Translations made on CurseForge. When a release is packaged, the packager replaces each
-- @localization line below with that language's translations from CurseForge, written as
-- L["KEY"] = "text" and assigned over the draft above. Anything nobody has translated there is
-- left out, so the draft stands. In a copy straight from git each line is only a comment.
do local L = translations.deDE --@localization(locale="deDE", format="lua_additive_table", handle-unlocalized="ignore")@
end
do local L = translations.esES --@localization(locale="esES", format="lua_additive_table", handle-unlocalized="ignore")@
end
do local L = translations.frFR --@localization(locale="frFR", format="lua_additive_table", handle-unlocalized="ignore")@
end
do local L = translations.itIT --@localization(locale="itIT", format="lua_additive_table", handle-unlocalized="ignore")@
end
do local L = translations.koKR --@localization(locale="koKR", format="lua_additive_table", handle-unlocalized="ignore")@
end
do local L = translations.ptBR --@localization(locale="ptBR", format="lua_additive_table", handle-unlocalized="ignore")@
end
do local L = translations.ruRU --@localization(locale="ruRU", format="lua_additive_table", handle-unlocalized="ignore")@
end
do local L = translations.zhCN --@localization(locale="zhCN", format="lua_additive_table", handle-unlocalized="ignore")@
end
do local L = translations.zhTW --@localization(locale="zhTW", format="lua_additive_table", handle-unlocalized="ignore")@
end

-- Latin American Spanish starts from the Spanish above, CurseForge's improvements included, and
-- then takes anything translated for its own client specifically.
local esMX = {}
for key, text in pairs(translations.esES) do esMX[key] = text end
translations.esMX = esMX
do local L = translations.esMX --@localization(locale="esMX", format="lua_additive_table", handle-unlocalized="ignore")@
end

-- CurseForge has no European Portuguese, so that client reads the Brazilian text as it stands.
translations.ptPT = translations.ptBR

-- enUS and enGB have no table of their own, so they get English straight through.
ns.L = setmetatable(translations[GetLocale()] or {}, { __index = enUS })
