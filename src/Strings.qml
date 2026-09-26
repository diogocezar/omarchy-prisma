pragma Singleton
import QtQuick

// UI strings. `language` is "auto" (follow the system locale) or one of the
// keys below; anything missing falls back to English. Add a language by
// adding a table — every key in `en` is used somewhere.
QtObject {
    id: root

    property string language: "auto"

    readonly property string resolved: {
        var lang = language === "auto" ? Qt.locale().name.split("_")[0] : language;
        return tables[lang] ? lang : "en";
    }

    readonly property var tables: ({
        en: {
            amber: "Amber", lime: "Lime", sky: "Sky blue", rose: "Rose",
            useTheme: "Use theme color", useThemeHint: "Every device on the theme accent, following theme changes",
            off: "Lighting off", themeColor: "Theme color", rainbow: "Rainbow",
            customColor: "Custom color", eachStatus: "A color per device",
            tooltip: "Prisma · %1",
            modeAll: "All together", modeEach: "Per device",
            color: "Color", theme: "Theme", colors: "Colors", effects: "More",
            accent: "Theme accent", foreground: "Theme text", themeSwatch: "Theme color %1",
            turnOff: "Off", sameAsAll: "Same as all", sameAsAllHint: "Follows the color set for all devices",
            hexPlaceholder: "#RRGGBB", hexInvalid: "Use a hex color like #FF4000",
            devices: "Devices", detecting: "Looking for RGB devices…",
            noDevices: "No RGB devices found",
            rescan: "Detect again", rescanHint: "Wireless devices are only found while awake: move them first",
            renameHint: "Click a name to rename it · click a row to pick its color",
            renameHintAll: "Click a name to rename it",
            renameEditing: "Enter saves · Esc cancels · empty restores",
            renameTooltip: "Rename",
            error: "Couldn't set the lights",
            red: "Red", orange: "Orange", yellow: "Yellow", green: "Green", turquoise: "Turquoise",
            cyan: "Cyan", blue: "Blue", purple: "Purple", pink: "Pink", white: "White",
            type_Motherboard: "Motherboard", type_DRAM: "Memory", type_GPU: "Graphics card",
            type_Cooler: "Cooler", "type_LED Strip": "LED strip", type_Keyboard: "Keyboard",
            type_Mouse: "Mouse", type_Mousemat: "Mouse pad", type_Headset: "Headset",
            "type_Headset Stand": "Headset stand", type_Gamepad: "Controller", type_Light: "Light",
            type_Speaker: "Speaker", type_Storage: "Storage", type_Case: "Case",
            type_Microphone: "Microphone", type_Accessory: "Accessory", type_Keypad: "Keypad",
            type_Laptop: "Laptop", type_Monitor: "Monitor", type_other: "Device"
        },
        pt: {
            amber: "Âmbar", lime: "Lima", sky: "Celeste", rose: "Rosa-choque",
            useTheme: "Usar cor do tema", useThemeHint: "Todos os dispositivos no destaque do tema, acompanhando as trocas de tema",
            off: "Iluminação desligada", themeColor: "Cor do tema", rainbow: "Arco-íris",
            customColor: "Cor personalizada", eachStatus: "Uma cor por dispositivo",
            tooltip: "Prisma · %1",
            modeAll: "Tudo junto", modeEach: "Por dispositivo",
            color: "Cor", theme: "Tema", colors: "Cores", effects: "Mais",
            accent: "Destaque do tema", foreground: "Texto do tema", themeSwatch: "Cor %1 do tema",
            turnOff: "Apagado", sameAsAll: "Igual a todos", sameAsAllHint: "Segue a cor definida para todos",
            hexPlaceholder: "#RRGGBB", hexInvalid: "Use uma cor hex como #FF4000",
            devices: "Dispositivos", detecting: "Procurando dispositivos RGB…",
            noDevices: "Nenhum dispositivo RGB encontrado",
            rescan: "Detectar de novo", rescanHint: "Sem fio só é encontrado acordado: mexa nele antes",
            renameHint: "Clique no nome para renomear · clique na linha para escolher a cor",
            renameHintAll: "Clique no nome para renomear",
            renameEditing: "Enter salva · Esc cancela · vazio restaura",
            renameTooltip: "Renomear",
            error: "Não foi possível aplicar as cores",
            red: "Vermelho", orange: "Laranja", yellow: "Amarelo", green: "Verde", turquoise: "Turquesa",
            cyan: "Ciano", blue: "Azul", purple: "Roxo", pink: "Rosa", white: "Branco",
            type_Motherboard: "Placa-mãe", type_DRAM: "Memória", type_GPU: "Placa de vídeo",
            type_Cooler: "Cooler", "type_LED Strip": "Fita de LED", type_Keyboard: "Teclado",
            type_Mouse: "Mouse", type_Mousemat: "Mousepad", type_Headset: "Headset",
            "type_Headset Stand": "Suporte de headset", type_Gamepad: "Controle", type_Light: "Luz",
            type_Speaker: "Caixa de som", type_Storage: "Armazenamento", type_Case: "Gabinete",
            type_Microphone: "Microfone", type_Accessory: "Acessório", type_Keypad: "Keypad",
            type_Laptop: "Notebook", type_Monitor: "Monitor", type_other: "Dispositivo"
        },
        es: {
            amber: "Ámbar", lime: "Lima", sky: "Celeste", rose: "Fucsia",
            useTheme: "Usar color del tema", useThemeHint: "Todos los dispositivos con el acento del tema, siguiendo los cambios de tema",
            off: "Iluminación apagada", themeColor: "Color del tema", rainbow: "Arcoíris",
            customColor: "Color personalizado", eachStatus: "Un color por dispositivo",
            tooltip: "Prisma · %1",
            modeAll: "Todo junto", modeEach: "Por dispositivo",
            color: "Color", theme: "Tema", colors: "Colores", effects: "Más",
            accent: "Acento del tema", foreground: "Texto del tema", themeSwatch: "Color %1 del tema",
            turnOff: "Apagado", sameAsAll: "Igual que todos", sameAsAllHint: "Sigue el color elegido para todos",
            hexPlaceholder: "#RRGGBB", hexInvalid: "Usa un color hex como #FF4000",
            devices: "Dispositivos", detecting: "Buscando dispositivos RGB…",
            noDevices: "No se encontraron dispositivos RGB",
            rescan: "Detectar de nuevo", rescanHint: "Los inalámbricos solo aparecen despiertos: muévelos antes",
            renameHint: "Haz clic en un nombre para renombrarlo · en la fila para elegir su color",
            renameHintAll: "Haz clic en un nombre para renombrarlo",
            renameEditing: "Enter guarda · Esc cancela · vacío restaura",
            renameTooltip: "Renombrar",
            error: "No se pudieron aplicar los colores",
            red: "Rojo", orange: "Naranja", yellow: "Amarillo", green: "Verde", turquoise: "Turquesa",
            cyan: "Cian", blue: "Azul", purple: "Morado", pink: "Rosa", white: "Blanco",
            type_Motherboard: "Placa base", type_DRAM: "Memoria", type_GPU: "Tarjeta gráfica",
            type_Cooler: "Refrigeración", "type_LED Strip": "Tira LED", type_Keyboard: "Teclado",
            type_Mouse: "Ratón", type_Mousemat: "Alfombrilla", type_Headset: "Auriculares",
            "type_Headset Stand": "Soporte de auriculares", type_Gamepad: "Mando", type_Light: "Luz",
            type_Speaker: "Altavoz", type_Storage: "Almacenamiento", type_Case: "Caja",
            type_Microphone: "Micrófono", type_Accessory: "Accesorio", type_Keypad: "Teclado auxiliar",
            type_Laptop: "Portátil", type_Monitor: "Monitor", type_other: "Dispositivo"
        },
        fr: {
            amber: "Ambre", lime: "Citron vert", sky: "Bleu ciel", rose: "Fuchsia",
            useTheme: "Couleur du thème", useThemeHint: "Tous les appareils sur l'accent du thème, qui suit les changements de thème",
            off: "Éclairage éteint", themeColor: "Couleur du thème", rainbow: "Arc-en-ciel",
            customColor: "Couleur personnalisée", eachStatus: "Une couleur par appareil",
            tooltip: "Prisma · %1",
            modeAll: "Tout ensemble", modeEach: "Par appareil",
            color: "Couleur", theme: "Thème", colors: "Couleurs", effects: "Plus",
            accent: "Accent du thème", foreground: "Texte du thème", themeSwatch: "Couleur %1 du thème",
            turnOff: "Éteint", sameAsAll: "Comme les autres", sameAsAllHint: "Suit la couleur choisie pour tous",
            hexPlaceholder: "#RRGGBB", hexInvalid: "Utilisez une couleur hex comme #FF4000",
            devices: "Appareils", detecting: "Recherche des appareils RGB…",
            noDevices: "Aucun appareil RGB trouvé",
            rescan: "Détecter à nouveau", rescanHint: "Les appareils sans fil ne sont trouvés qu'éveillés : bougez-les d'abord",
            renameHint: "Cliquez sur un nom pour le renommer · sur la ligne pour choisir sa couleur",
            renameHintAll: "Cliquez sur un nom pour le renommer",
            renameEditing: "Entrée valide · Échap annule · vide restaure",
            renameTooltip: "Renommer",
            error: "Impossible d'appliquer les couleurs",
            red: "Rouge", orange: "Orange", yellow: "Jaune", green: "Vert", turquoise: "Turquoise",
            cyan: "Cyan", blue: "Bleu", purple: "Violet", pink: "Rose", white: "Blanc",
            type_Motherboard: "Carte mère", type_DRAM: "Mémoire", type_GPU: "Carte graphique",
            type_Cooler: "Refroidissement", "type_LED Strip": "Bande LED", type_Keyboard: "Clavier",
            type_Mouse: "Souris", type_Mousemat: "Tapis de souris", type_Headset: "Casque",
            "type_Headset Stand": "Support de casque", type_Gamepad: "Manette", type_Light: "Lumière",
            type_Speaker: "Enceinte", type_Storage: "Stockage", type_Case: "Boîtier",
            type_Microphone: "Microphone", type_Accessory: "Accessoire", type_Keypad: "Pavé",
            type_Laptop: "Portable", type_Monitor: "Écran", type_other: "Appareil"
        },
        de: {
            amber: "Bernstein", lime: "Limette", sky: "Himmelblau", rose: "Fuchsia",
            useTheme: "Themenfarbe verwenden", useThemeHint: "Alle Geräte im Akzent des Themas, folgt Themenwechseln",
            off: "Beleuchtung aus", themeColor: "Themenfarbe", rainbow: "Regenbogen",
            customColor: "Eigene Farbe", eachStatus: "Eine Farbe pro Gerät",
            tooltip: "Prisma · %1",
            modeAll: "Alle zusammen", modeEach: "Pro Gerät",
            color: "Farbe", theme: "Thema", colors: "Farben", effects: "Mehr",
            accent: "Akzent des Themas", foreground: "Text des Themas", themeSwatch: "Themenfarbe %1",
            turnOff: "Aus", sameAsAll: "Wie alle", sameAsAllHint: "Folgt der Farbe für alle Geräte",
            hexPlaceholder: "#RRGGBB", hexInvalid: "Hex-Farbe wie #FF4000 verwenden",
            devices: "Geräte", detecting: "Suche nach RGB-Geräten…",
            noDevices: "Keine RGB-Geräte gefunden",
            rescan: "Erneut suchen", rescanHint: "Funkgeräte werden nur wach gefunden: vorher bewegen",
            renameHint: "Zum Umbenennen auf einen Namen klicken · auf die Zeile für die Farbe",
            renameHintAll: "Zum Umbenennen auf einen Namen klicken",
            renameEditing: "Enter speichert · Esc bricht ab · leer setzt zurück",
            renameTooltip: "Umbenennen",
            error: "Farben konnten nicht gesetzt werden",
            red: "Rot", orange: "Orange", yellow: "Gelb", green: "Grün", turquoise: "Türkis",
            cyan: "Cyan", blue: "Blau", purple: "Lila", pink: "Pink", white: "Weiß",
            type_Motherboard: "Mainboard", type_DRAM: "Arbeitsspeicher", type_GPU: "Grafikkarte",
            type_Cooler: "Kühler", "type_LED Strip": "LED-Streifen", type_Keyboard: "Tastatur",
            type_Mouse: "Maus", type_Mousemat: "Mauspad", type_Headset: "Headset",
            "type_Headset Stand": "Headset-Ständer", type_Gamepad: "Controller", type_Light: "Licht",
            type_Speaker: "Lautsprecher", type_Storage: "Speicher", type_Case: "Gehäuse",
            type_Microphone: "Mikrofon", type_Accessory: "Zubehör", type_Keypad: "Keypad",
            type_Laptop: "Laptop", type_Monitor: "Monitor", type_other: "Gerät"
        }
    })

    function t(key, arg) {
        var table = tables[resolved] || tables.en;
        var s = table[key] !== undefined ? table[key] : (tables.en[key] !== undefined ? tables.en[key] : key);
        return arg !== undefined ? s.replace("%1", arg) : s;
    }

    function typeLabel(type) { return t("type_" + (tables.en["type_" + type] ? type : "other")); }
}
