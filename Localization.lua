local addonName, addon = ...

--<GLOBALS
local _G = _G
local GetLocale = _G.GetLocale
local pairs = _G.pairs
local rawset = _G.rawset
local setmetatable = _G.setmetatable
local tostring = _G.tostring
--GLOBALS>

local L = setmetatable({}, {
	__index = function(self, key)
		if key ~= nil then
			--[===[@debug@
			addon:Debug('Missing locale', tostring(key))
			--@end-debug@]===]
			rawset(self, key, tostring(key))
		end
		return tostring(key)
	end,
})
addon.L = L

L["QUIVER_TAG"] = "Qu"
L["AMMO_TAG"] = "Am"
L["SOUL_BAG_TAG"] = "So"
L["LEATHERWORKING_BAG_TAG"] = "Le"
L["INSCRIPTION_BAG_TAG"] = "In"
L["HERB_BAG_TAG"] = "He"
L["ENCHANTING_BAG_TAG"] = "En"
L["ENGINEERING_BAG_TAG"] = "Eg"
L["KEYRING_TAG"] = "Ke"
L["GEM_BAG_TAG"] = "Ge"
L["MINING_BAG_TAG"] = "Mi"
L["TACKLE_BOX_TAG"] = "Fi"

-- Get LibBabble-Inventory-3.0
addon.BI = LibStub('LibBabble-Inventory-3.0'):GetLookupTable()

--------------------------------------------------------------------------------
-- Locales from localization system
--------------------------------------------------------------------------------

-- %Localization: adibags
-- THE END OF THE FILE IS UPDATED BY A SCRIPT
-- ANY CHANGE BELOW THESES LINES WILL BE LOST
-- CHANGES SHOULD BE MADE USING http://www.wowace.com/addons/adibags/localization/

-- @noloc[[

------------------------ enUS ------------------------


-- AdiBags.lua
L["AdiBags Anchor"] = true
L["Backpack"] = true
L["Bank"] = true

-- DefaultFilters.lua
L["Ammunition"] = true
L["Check sets that should be merged into a unique \"Sets\" section. This is obviously a per-character setting."] = true
L["Check this so armors are dispatched in four sections by type."] = true
L["Check this to display one individual section per set. If this is disabled, there will be one big \"Sets\" section."] = true
L["Consider gems as a subcategory of trade goods"] = true
L["Consider glyphs as a subcategory of trade goods"] = true
L["Equipment"] = true
L["Four general sections."] = true
L["Gear manager item sets"] = true
L["Gems are trade goods"] = true
L["Glyphs are trade goods"] = true
L["Item category"] = true
L["Jewelry"] = true
L["Trinket"] = true
L["Merged sets"] = true
L["One section per item slot."] = true
L["One section per set"] = true
L["Only one section."] = true
L["Please note this filter matchs every item. Any filter with lower priority than this one will have no effect."] = true
L["Put any item that can be equipped (including bags) into the \"Equipment\" section."] = true
L["Put items categorized as keys in their own section."] = true
L["Put items belonging to one or more sets of the built-in gear manager in specific sections."] = true
L["Put items in sections depending on their first-level category at the Auction House."] = true
L["Put quest-related items in their own section."] = true
L["Quest Items"] = true
L["Mythic Keystone"] = true
L["Put mythic keystone items into their own section."] = true
L["Sirus"] = true
L["Put Sirus-specific items (Black Diamonds, legendary gems) in their own section."] = true
L["Section setup"] = true
L["Select the sections in which the items should be dispatched."] = true
L["Select which first-level categories should be split by sub-categories."] = true
L["Set: %s"] = true
L["Sets"] = true
L["Split armors by types"] = true
L["Split by subcategories"] = true
L["Decorate."] = true
L["Put decorated items in their own section."] = true
L["Decorative item"] = true

-- modules/ExpiringItems.lua
L["Expiring Items"] = true
L["Put items that have an expiration time or lifetime in a specific section."] = true
L["Enable Expiring Items Category"] = true
L["Check this to automatically group items that have an expiration time or lifetime."] = true
L["Temporary items"] = true

-- Options.lua
L["... including incomplete stacks"] = true
L["Adjust the maximum height of the bags, relative to screen size."] = true
L["Adjust the maximum number of items per row."] = true
L["Anchored"] = true
L["Background colors"] = true
L["Bag type"] = true
L["Bags"] = true
L["By category, subcategory, quality and item level (default)"] = true
L["By name"] = true
L["By quality and item level"] = true
L["Change stacking at merchants', auction house, bank, mailboxes or when trading."] = true
L["Check this to display a bag type tag in the top left corner of items."] = true
L["Check this to display a colored border around items, based on item quality."] = true
L["Check this to display an indicator on quest items."] = true
L["Check this to have poor quality items dimmed."] = true
L["Check to enable this module."] = true
L["Click there to reset the bag positions and sizes."] = true
L["Click to toggle the bag anchor."] = true
L["Configure"] = true
L["Dim junk"] = true
L["Enabled"] = true
L["Fill lines at most"] = true
L["Filters are used to dispatch items in bag sections. One item can only appear in one section. If the same item is selected by several filters, the one with the highest priority wins."] = true
L["Filters"] = true
L["Group sections of same category"] = true
L["Items"] = true
L["Keep all stacks together."] = true
L["Layout priority"] = true
L["Lock anchor"] = true
L["Manual"] = true
L["Maximum bag height"] = true
L["Maximum row width"] = true
L["Merge free space"] = true
L["Merge incomplete stacks with complete ones."] = true
L["Merge stackable items"] = true
L["Merge unstackable items"] = true
L["Opacity"] = true
L["Plugins"] = true
L["Position mode"] = true
L["Priority"] = true
L["Quality highlight"] = true
L["Quest indicator"] = true
L["Reset position"] = true
L["Scale"] = true
L["Select how items should be sorted within each section."] = true
L["Select how the bag are positionned."] = true
L["Separate incomplete stacks."] = true
L["Separate unstackable items."] = true
L["Show every distinct item stacks."] = true
L["Show only one free slot for each kind of bags."] = true
L["Show only one slot of items that can be stacked."] = true
L["Show only one slot of items that cannot be stacked."] = true
L["Sorting order"] = true
L["Strictly keep ordering"] = true
L["Toggle and configure item filters."] = true
L["Toggle and configure plugins."] = true
L["Uncheck this to disable AdiBags."] = true
L["Unlock anchor"] = true
L["Use this to adjust the bag scale."] = true
L["Use this to adjust the quality-based border opacity. 100% means fully opaque."] = true
L["Virtual stacks display in one place items that actually spread over several bag slots."] = true
L["Virtual stacks"] = true
L["When trading:"] = true

-- modules/CurrencyFrame.lua
L["Currencies to show"] = true
L["Currency"] = true
L["Display character currency at bottom left of the backpack."] = true
L["Hide zeroes"] = true
L["Ignore currencies with null amounts."] = true


-- modules/DataSource.lua
L["Bag usage format"] = true
L["Check this to display an icon after usage of each type of bags."] = true
L["Check this to display an textual tag before usage of each type of bags."] = true
L["Check this to display only one value counting all equipped bags, ignoring their type."] = true
L["Check this to show space at your bank in the plugin."] = true
L["Free space / total space"] = true
L["Free space"] = true
L["LDB Plugin"] = true
L["Merge bag types"] = true
L["Provides a LDB data source to be displayed by LDB display addons."] = true
L["Select how bag usage should be formatted in the plugin."] = true
L["Show bag type icons"] = true
L["Show bag type tags"] = true
L["Show bank usage"] = true
L["Space in use / total space"] = true
L["Space in use"] = true
L["Item level"] = true
L["Which color scheme should be used to display the item level ?"] = true
L["Color scheme"] = true
L["None"] = true
L["Do not show levels under this threshold."] = true
L["Do not show level of heirloom items."] = true
L["Do not show level of poor quality items."] = true
L["Do not show level of items that cannot be equipped."] = true
L["Same as InventoryItemLevels"] = true
L["Related to player level"] = true
L["Ignore heirloom items"] = true
L["Only equippable items"] = true


-- modules/FilterOverride.lua
L["Add association"] = true
L["Allow you manually redefine the section in which an item should be put. Simply drag an item on the section title."] = true
L["Are you sure you want to remove this section ?"] = true
L["Category"] = true
L["Click on a item to remove it from the list. You can drop an item on the empty slot to add it to the list."] = true
L["Click on this button to create the new association."] = true
L["Drop your item there to add it to this section."] = true
L["Enter the name of your custom section"] = true
L["Enter the name, link or itemid of the item to associate with the section. You can also drop an item into this box."] = true
L["Item"] = true
L["Manual filtering"] = true
L["New Override"] = true
L["Remove"] = true
L["Section category"] = true
L["Section"] = true
L["Select the category of the section to associate. This is used to group sections together."] = true
L["Use this section to define any item-section association."] = true

-- modules/Junk.lua
L["Exclude list"] = true
L["Include list"] = true
L["Included categories"] = true
L["Items in this list are always considered as junk. Click an item to remove it from the list."] = true
L["Items in this list are never considered as junk. Click an item to remove it from the list."] = true
L["Junk category"] = true
L["Low quality items"] = true
L["Put items of poor quality or labeled as junk in the \"Junk\" section."] = true

-- modules/MoneyFrame.lua
L["Display character money at bottom right of the backpack."] = true
L["Money"] = true

-- modules/NewItemTracking.lua
L["Click to reset item status."] = true
L["Highlight color"] = true
L["Highlight scale"] = true
L["Ignore low quality items"] = true
L["New item highlight"] = true
L["New"] = true
L["Reset new items"] = true
L["Track new items in each bag, displaying a glowing aura over them and putting them in a special section. \"New\" status can be reset by clicking on the small \"N\" button at top left of bags."] = true
L["Track new items"] = true

-- modules/SearchHighlight.lua
L["Enter a text to search in item names."] = true
L["Item search"] = true
L["Provides a text widget at top of the backpack where you can type (part of) an item name to locate it in your bags."] = true

-- modules/SectionVisibilityDropdown.lua
L["Add a dropdown menu to bags that allow to hide the sections."] = true
L["Check this to show this section. Uncheck to hide it."] = true
L["Click to select which sections should be shown or hidden. Section visibility is common to all bags."] = true
L["Section visibility button"] = true
L["Section visibility"] = true
L["Show %s"] = true

-- modules/TidyBags.lua
L["Check this so tidying is performed when you close the loot windows or you leave merchants, mailboxes, etc."] = true
L["Click to tidy bags."] = true
L["Semi-automated tidy"] = true
L["Tidy bags"] = true
L["Tidy your bags by clicking on the small \"T\" button at the top left of bags. Special bags with free slots will be filled with matching items and stackable items will be stacked to save space."] = true

-- modules/TooltipInfo.lua
L["AH category"] = true
L["AH subcategory"] = true
L["Add more information in tooltips related to items in your bags."] = true
L["Always"] = true
L["Bag number"] = true
L["Container information"] = true
L["Filter"] = true
L["Filtering information"] = true
L["Item information"] = true
L["Maximum stack size"] = true
L["Never"] = true
L["Show container information..."] = true
L["Show filtering information..."] = true
L["Show item information..."] = true
L["Slot number"] = true
L["Tooltip information"] = true
L["Virtual stack slots"] = true
L["When alt is held down"] = true
L["When any modifier key is held down"] = true
L["When ctrl is held down"] = true
L["When shift is held down"] = true

-- widgets/BagSlots.lua
L["Click to purchase"] = true
L["Equipped bags"] = true
L["Right-click to try to empty this bag."] = true

-- widgets/Config-ItemList.lua
L["Click or drag this item to remove it."] = true
L["Drop an item there to add it to the list."] = true

-- widgets/ContainerFrame.lua
L["Bag #%d"] = true
L["Bank bag #%d"] = true
L["Click to toggle the equipped bag panel, so you can change them."] = true
L["Close"] = true
L["Keyring"] = true
L["Reset bag position"] = true
L["Unlock Anchor"] = true
L["Manual Filtering"] = true
L["Settings"] = true
L["Manual mode click behavior"] = true
L["Choose how mouse clicks work in manual mode:\n\nNormal: Left-click opens menu, Shift+Left-click moves bag\nSwapped: Left-click moves bag, Shift+Left-click opens menu"] = true
L["Normal"] = true
L["Swapped"] = true
L["Show anchor highlight"] = true
L["Show green/orange highlight when hovering over bag anchors in manual mode"] = true
L["Show anchor tooltip"] = true
L["Show tooltip when hovering over bag anchors in both modes"] = true
L["Anchored"] = true
L["Mode"] = true
L["Manual"] = true
L["Click"] = true
L["Shift-Click"] = true
L["Right-Click"] = true
L["Alt-Left-Click"] = true
L["to toggle the anchor."] = true
L["to open bag menu."] = true
L["to open AdiBags options."] = true
L["to toggle anchor mode."] = true
L["to move bag container."] = true
L["mode."] = true

local locale = GetLocale()

	------------------------ ruRU ------------------------
if locale == 'ruRU' then
	L["Mythic Keystone"] = "М+ Ключ"
	L["Put mythic keystone items into their own section."] = "Поместить мифические ключи в отдельную секцию."
	L["Sirus"] = "Sirus"
	L["Put Sirus-specific items (Black Diamonds, legendary gems) in their own section."] = "Поместить специфичные для Sirus предметы (Чёрные бриллианты, легендарные самоцветы) в отдельную секцию."
	L["Add a dropdown menu to bags that allow to hide the sections."] = "Добавить выпадающее меню для сумок, в котором можно настроить отображение секций."
	L["Add association"] = "Добавить объединение"
	L["Add more information in tooltips related to items in your bags."] = "Добавить Дополнительную информацию во всплывающих подсказках, касающихся предметов, в вашей сумке"
	L["AdiBags Anchor"] = "AdiBags Якорь"
	L["Adjust the maximum height of the bags, relative to screen size."] = "Регулировка максимальной высоты сумок, относительно размеру экрана."
	L["Adjust the maximum number of items per row."] = "регулировка максимально количества предметов в ряду."
	L["AH category"] = "Категория аукциона"
	L["AH subcategory"] = "Подкатегория аукциона"
	L["Allow you manually redefine the section in which an item should be put. Simply drag an item on the section title."] = "Позволяет вручную изменять секцию в которую следует помещать предмет. Просто перетащите элемент на название раздела."
	L["Always"] = "Всегда"
	L["AMMO_TAG"] = "Бп"
	L["Ammunition"] = "Боеприпасы"
	L["Anchored"] = "Закрепленные"
	L["Background colors"] = "Цвета фона"
	L["Backpack"] = "Рюкзак"
	L["Bag #%d"] = "Сумка #%d"
	L["Bag number"] = "Номер сумки"
	L["Bags"] = "Сумки"
	L["Bag type"] = "Тип сумки"
	L["Bag usage format"] = "Формат использования сумки"
	L["Bank"] = "Банк"
	L["Bank bag #%d"] = "Сумка банка #%d"
	L["By category, subcategory, quality and item level (default)"] = "По категории, под-категории, качеству и уровню предмета (по умолчанию)"
	L["By name"] = "По имени"
	L["By quality and item level"] = "По качеству и уровню"
	L["Category"] = "Категория"
	L["Check sets that should be merged into a unique \"Sets\" section. This is obviously a per-character setting."] = "Отметьте какие наборы должны быть объединены в особую секцию \"Наборы\". Конечно же это настройка, для каждого персонажа отдельно."
	L["Check this so armors are dispatched in four sections by type."] = "Отметьте это, и броня будет разделяться на четыре секции в зависимости от ее типа."
	L["Check this so tidying is performed when you close the loot windows or you leave merchants, mailboxes, etc."] = "Отметьте это, если хотите что бы уборка в сумках происходила при каждом закрытии окна сбора добычи, торговли, почтового ящика и т.п."
	L["Check this to display a bag type tag in the top left corner of items."] = "Поставте галочку, чтобы отображать тег сумки в левом верхнем углу иконки предмета."
	L["Check this to display a colored border around items, based on item quality."] = "Отметьте это, чтобы подкрашивать края предметов исходя из их качества."
	L["Check this to display an icon after usage of each type of bags."] = "Поставьте тут галочку для отображения иконки после использования каждого из видов сумок." -- Needs review
	L["Check this to display an indicator on quest items."] = "Поставьте тут галочку чтобы отображать индикатор на предметах, необходимых для задания."
	L["Check this to display an textual tag before usage of each type of bags."] = "Отметьте это, если хотите что бы отображалась текстовая пометка перед использованием каждого из типов сумок."
	L["Check this to display one individual section per set. If this is disabled, there will be one big \"Sets\" section."] = "Отметьте это, если хотите что бы для каждого набора вещей была отдельная секция. Если этот пункт отключен, используется одна большая секция \"Наборы\"."
	L["Check this to display only one value counting all equipped bags, ignoring their type."] = "Отметьте это, если хотите что бы отображалась только количество пустых слотов во всех сумках, несмотря на тип сумок."
	L["Check this to have poor quality items dimmed."] = "Поставьте галочку, для отабражения низкова уровня вешей затемнёным цветом."
	L["Check this to show space at your bank in the plugin."] = "Отметьте это, если хотите чтобы отображались промежутки в окне банка вашего плагина." -- Needs review
	L["Check this to show this section. Uncheck to hide it."] = "Отметьте это что бы показывать эту секцию, или снимите отметку что бы ее скрыть."
	L["Check to enable this module."] = "Поставьте галочку для включения данного модуля."
	L["Click on this button to create the new association."] = "Кликните на кнопку, что бы создать новую ассоциацию."
	L["Click there to reset the bag positions and sizes."] = "Кликните тут чтобы сбросить расположение сумок и их размер."
	L["Click to purchase"] = "Кликните чтобы купить"
	L["Click to reset item status."] = "Кликните чтобы сбросить статус предметов."
	L["Click to select which sections should be shown or hidden. Section visibility is common to all bags."] = "Кликните что бы выбрать какие секции должны показываться, а какие скрываться. Настройки видимости секций общие для всех сумок."
	L["Click to tidy bags."] = "Кликните, что бы прибраться в сумках."
	L["Click to toggle the bag anchor."] = "Кликните чтобы переключить якорь сумки."
	L["Click to toggle the equipped bag panel, so you can change them."] = "Кликните для переключения панели надетых сумок, так что вы можете их изменить."
	L["Close"] = "Закрыть"
	L["Configure"] = "Настройка"
	L['Currencies to show'] = "Отображать валюту"
	L['Hide zeroes'] = "Прятать пустую валюту"
	L['Ignore currencies with null amounts.'] = "Игнорировать валюты с нулевым количеством"
	L["Drop an item there to add it to the list."] = "Перетащите туда предмет, чтобы добавить его в список."
	L["Consider gems as a subcategory of trade goods"] = "Рассматривать самоцветы как подкатегорию хозяйственных товаров"
	L["Consider glyphs as a subcategory of trade goods"] = "Рассматривать символы как подкатегорию хозяйственных товаров"
	L["Container information"] = "Информация о контейнере" -- Needs review
	L["Currency"] = "Валюта"
	L["Dim junk"] = "Затемнять хлам"
	L["Display character currency at bottom left of the backpack."] = "Показывать количество золота у персонажа в нижней левой стороне окна сумок."
	L["Display character money at bottom right of the backpack."] = "Отображать деньги персонажа в нижнем правом углу рюкзака."
	L["Drop your item there to add it to this section."] = "Чтобы добавить предмет в этот раздел, переместите его туда. "
	L["Enabled"] = "Включен"
	L["ENCHANTING_BAG_TAG"] = "Чры"
	L["ENGINEERING_BAG_TAG"] = "Эн"
	L["Enter a text to search in item names."] = "Введите текст для поиска предмета по названию."
	L["Enter the name, link or itemid of the item to associate with the section. You can also drop an item into this box."] = "Введите название, ссылку или ID предмета, что бы связать ее с секцией. Так же вы можете просто перетащить предмет в окошко."
	L["Enter the name of your custom section"] = "Введите название секции, с которой вы хотите связать вещь."
	L["Equipment"] = "Экипировка"
	L["Equipped bags"] = "Сумки персонажа"
	L["Fill lines at most"] = "Заполнять линии полностью"
	L["Filter"] = "Фильтр"
	L["Filtering information"] = "Фильтрование информации"
	L["Filters"] = "Фильтры"
	L["Filters are used to dispatch items in bag sections. One item can only appear in one section. If the same item is selected by several filters, the one with the highest priority wins."] = "Фильтры используются для группировки ваших вещей. Одна вещь может находиться только в одной из секций. Если одна вещь входит в несколько фильтров, используется тот фильтр, чей приоритет выше."
	L["Four general sections."] = "Четыре общих секции."
	L["Free space"] = "Свободно"
	L["Free space / total space"] = "Свободно / всего места"
	L['Item level']	= "Уровень предметов" -- ItemLevel.lua
	L['Which color scheme should be used to display the item level ?'] = "Какую цветовую схему следует использовать для отображения уровня предметов?" -- ItemLevel.lua
	L['Color scheme'] = "Цветовая схема" -- ItemLevel.lua
	L['None'] = "Стандарт" -- ItemLevel.lua
	L['Do not show levels under this threshold.'] = "Не показывать уровни ниже этого порогового значения." -- ItemLevel.lua
	L['Do not show level of heirloom items.'] = "Не показывать уровень у наследуемых предметов." -- ItemLevel.lua
	L['Do not show level of poor quality items.'] = "Не показывать уровень у низкоуровневых предметов." -- ItemLevel.lua
	L['Do not show level of items that cannot be equipped.'] = "Не показывать уровень предметов которые нельзя надеть." -- ItemLevel.lua
	L['Same as InventoryItemLevels'] = "Зависимость цвета от уровня предметов" -- ItemLevel.lua
	L['Related to player level'] = "Зависимость от уровня персонажа" -- ItemLevel.lua
	L['Ignore heirloom items'] = "Игнорировать наследуемые предметы" -- ItemLevel.lua
	L['Only equippable items'] = "Отображать только у оснащаемых предметов" -- ItemLevel.lua
	L["Gear manager item sets"] = "Предметы наборов управления экипировкой"
	L["GEM_BAG_TAG"] = "См"
	L["Gems are trade goods"] = "Самоцветы это Хозяйственные товары"
	L["Glyphs are trade goods"] = "Символы это Хозяйственные товары"
	L["Group sections of same category"] = "Группировать секции одной категории"
	L["HERB_BAG_TAG"] = "Тр"
	L["Highlight color"] = "Цвет подсвечивания"
	L["Highlight scale"] = "Масштаб подсвечивания"
	L["Ignore low quality items"] = "Игнорировать вещи низкого качества."
	L["... including incomplete stacks"] = "... включая не полные стопки"
	L["INSCRIPTION_BAG_TAG"] = "Нч"
	L["Item"] = "Предмет"
	L["Item category"] = "Категория предмета"
	L["Item information"] = "Информация о предмете"
	L["Items"] = "Предметы"
	L["Decorate."] = "Декоративные предметы/оружия"
	L["Put decorated items in their own section."] = "Поместить предметы связанные с трансмогрификацией в свою секцию."
	L["Decorative item"] = "Декоративный предмет"
	L["Item search"] = "Поиск предмета"
	L["Jewelry"] = "Бижутерия"
	L["Trinket"] = "Аксессуары"
	L["Temporary items"] = "Временные предметы"
	L["Expiring Items"] = "Временные предметы"
	L["Put items that have an expiration time or lifetime in a specific section."] = "Поместите предметы, у которых есть время или срок действия в специальную секцию."
	L["Enable Expiring Items Category"] = "Включить категорию временных предметов"
	L["Check this to automatically group items that have an expiration time or lifetime."] = "Включите это, чтобы автоматически группировать предметы, у которых есть срок действия."
	L["KEYRING_TAG"] = "Клч"
	L["Keyring"] = "Связка ключей"
	L["Layout priority"] = "Приоритет слоя"
	L["LDB Plugin"] = "Плагин LDB"
	L["LEATHERWORKING_BAG_TAG"] = "Кж"
	L["Lock anchor"] = "Блокировать якорь"
	L["Manual"] = "В ручную"
	L["Manual filtering"] = "Ручная фильтрация"
	L["Maximum bag height"] = "Максимальная высота сумки"
	L["Maximum row width"] = "Максимальная ширина ряда"
	L["Maximum stack size"] = "Максимальный размер стопки"
	L["Merge bag types"] = "Объединить типы сумок"
	L["Merged sets"] = "Объединенные наборы"
	L["Merge incomplete stacks with complete ones."] = "Объединять не полные стопки, с полными."
	L["Merge stackable items"] = "Складывать в стопки вещи, которые могут быть сложены."
	L["MINING_BAG_TAG"] = "Гд"
	L["Money"] = "Валюта"
	L["Never"] = "Никогда"
	L["New"] = "Новое"
	L["New item highlight"] = "Подсвечивать новые предметы"
	L["New Override"] = "Новое перераспределение" -- Needs review
	L["One section per item slot."] = "Для каждого слота доспехов, своя секция."
	L["One section per set"] = "Одна секция на набор"
	L["Only one section."] = "Только одна секция"
	L["Opacity"] = "Непрозрачность"
	L["Please note this filter matchs every item. Any filter with lower priority than this one will have no effect."] = "Имейте ввиду, что этот фильтр будет использоваться для всех вещей. Любой фильтр с меньшим приоритетом чем этот, не будет применяться."
	L["Plugins"] = "Плагины"
	L["Position mode"] = "Режим позиционирования" -- Needs review
	L["Priority"] = "Приоритет"
	L["Provides a LDB data source to be displayed by LDB display addons."] = "Позволяет отображать источник LDB данных другими аддонами для отображения LDB." -- Needs review
	L["Provides a text widget at top of the backpack where you can type (part of) an item name to locate it in your bags."] = "Добавляет виджет сверху окна сумок, с помощью которого, вы можете отыскать вещь, вводя ее название (или его часть) в специальное поле."
	L["Put any item that can be equipped (including bags) into the \"Equipment\" section."] = "Поместить все предметы которые могут быть одеты на персонажа (включая сумки) в секцию \"Экипировка\""
	L["Put items categorized as keys in their own section."] = "Поместите элементы, отнесенные к категории ключей, в отдельный раздел." -- Needs review
	L["Put items belonging to one or more sets of the built-in gear manager in specific sections."] = "Помещает вещи, являющиеся частью одного из наборов, созданных с помощью управления экипировкой, в отдельные секции."
	L["Put items in sections depending on their first-level category at the Auction House."] = "Раскладывать вещи в сумках, используя общие категории аукциона."
	L["Put items of poor quality or labeled as junk in the \"Junk\" section."] = "Поместить предметы низкого качества или помеченных как хлам с секцию \"Хлам\"."
	L["Put quest-related items in their own section."] = "Поместить предметы связанные с заданием в свою секцию."
	L["Quality highlight"] = "Подсвечивать в зависимости от качества"
	L["Quest indicator"] = "Индикатор задания"
	L["Quest Items"] = "Предметы, необходимые для задания"
	L["QUIVER_TAG"] = "Клчн"
	L["Reset new items"] = "Сброс новых предметов"
	L["Reset position"] = "Сброс расположения"
	L["Right-click to try to empty this bag."] = "Кликните правой кнопкой, что бы попытаться опустошить эту сумку."
	L["Scale"] = "Масштаб"
	L["Section"] = "Секция"
	L["Section category"] = "Категория секции"
	L["Section setup"] = "Настройки секции"
	L["Section visibility"] = "Видимость секции"
	L["Section visibility button"] = "Кнопка отображения секций"
	L["Select how bag usage should be formatted in the plugin."] = "Выберите способ, которым следует упорядочивать использование сумок плагином." -- Needs review
	L["Select how items should be sorted within each section."] = "Выберите как предметы должны сортироваться в пределах каждой секции."
	L["Select how the bag are positionned."] = "Выбрать то, как окно сумок будет расположено на экране."
	L["Select the category of the section to associate. This is used to group sections together."] = "Выберите категорию секции для того, что бы ее связать. Это необходимо для того, чтобы сгруппировать секции вместе."
	L["Select the sections in which the items should be dispatched."] = "Укажите секцию, в которой вещи необходимо разделить" -- Needs review
	L["Select which first-level categories should be split by sub-categories."] = "Укажите, какие общие категории должны быть разделены на субкатегории."
	L["Semi-automated tidy"] = "Полуавтоматическая уборка"
	L["Sets"] = "Наборы"
	L["Set: %s"] = "Набор: %s"
	L["Show bag type icons"] = "Показать иконку типа сумки"
	L["Show bag type tags"] = "Показать тег типа сумки"
	L["Show bank usage"] = "Показать использование банка"
	L["Show container information..."] = "Показать данные контейнера..."
	L["Show filtering information..."] = "Показать данные фильтрации..."
	L["Show item information..."] = "Показать данные о вещи..."
	L["Show only one free slot for each kind of bags."] = "Показывать только один свободный слот для каждого типа сумок"
	L["Show only one slot of items that can be stacked."] = "Показывать только один слот для вещей, которые можно сложить в стопки"
	L["Show only one slot of items that cannot be stacked."] = "Показывать только один слот вещей, которые не могут быть сложены в стопки"
	L["Show %s"] = "Показать %s"
	L["Slot number"] = "Номер слота"
	L["Sorting order"] = "Порядок сортировки"
	L["SOUL_BAG_TAG"] = "Кд"
	L["Space in use"] = "Исп. места"
	L["Space in use / total space"] = "Использовано / всего места"
	L["Split armors by types"] = "Разделять доспехи по типам"
	L["Split by subcategories"] = "Разделить по субкатегориям"
	L["Strictly keep ordering"] = "Строго соблюдать порядок"
	L["Tidy bags"] = "Чистыйе сумки"
	L["Tidy your bags by clicking on the small \"T\" button at the top left of bags. Special bags with free slots will be filled with matching items and stackable items will be stacked to save space."] = "Убраться в ваших сумках можно нажав небольшую кнопку \"Т\", которая находится верхней левой стороне окна сумок. Специальные сумки будут заполнены подходящими для них предметами, и вещи которые можно сложить, будут сложены в стопки для экономии места."
	L["Toggle and configure item filters."] = "Переключение и настройка фильтров предмета."
	L["Toggle and configure plugins."] = "Переключение и настройка плагина."
	L["Tooltip information"] = "Информация подсказки"
	L["Track new items"] = "Следить за новыми предметами"
	L["Track new items in each bag, displaying a glowing aura over them and putting them in a special section. \"New\" status can be reset by clicking on the small \"N\" button at top left of bags."] = "Отслеживать новые предметы в каждой сумке, подсвечивать их и помещать в отдельную секцию. Статус \"Новое\" может быть сброшен кликом по небольшой кнопке \"N\" находящейся, в верхней левой стороне окна сумок."
	L["Uncheck this to disable AdiBags."] = "Снимите галочку штобы выключить AdiBags."
	L["Reset bag position"] = "Сброс позиции сумки"
	L["Unlock Anchor"] = "Разблокировать якорь"
	L["Manual Filtering"] = "Ручная фильтрация"
	L["Settings"] = "Настройки"
	L["Manual mode click behavior"] = "Поведение кликов в ручном режиме"
	L["Choose how mouse clicks work in manual mode:\n\nNormal: Left-click opens menu, Shift+Left-click moves bag\nSwapped: Left-click moves bag, Shift+Left-click opens menu"] = "Выберите как работают клики мыши в ручном режиме:\n\nОбычный: Левый клик открывает меню, Shift+Левый клик перемещает сумку\nПереключенный: Левый клик перемещает сумку, Shift+Левый клик открывает меню"
	L["Normal"] = "Обычный"
	L["Swapped"] = "Переключенный"
	L["Show anchor highlight"] = "Подсветка якоря"
	L["Show green/orange highlight when hovering over bag anchors in manual mode"] = "Зеленая/оранжевая подсветка при наведении на якорь в ручном режиме"
	L["Show anchor tooltip"] = "Подсказка якоря"
	L["Show tooltip when hovering over bag anchors in both modes"] = "Показывать подсказку при наведении на якорь в обоих режимах"
	L["Anchored"] = "Якорный"
	L["Mode"] = "Режим"
	L["Manual"] = "Ручной"
	L["Click"] = "Клик"
	L["Shift-Click"] = "Shift-Клик"
	L["Right-Click"] = "Правый клик"
	L["Alt-Left-Click"] = "Alt-Левый клик"
	L["to toggle the anchor."] = "переключить якорь."
	L["to open bag menu."] = "открыть меню сумки."
	L["to open AdiBags options."] = "открыть настройки AdiBags."
	L["to toggle anchor mode."] = "переключить режим якоря."
	L["to move bag container."] = "переместить контейнер сумки."
	L["mode."] = "режим."
	L["Unlock anchor"] = "Разблок. якорь"
	L["Use this section to define any item-section association."] = "Использовать эту секцию, для определения любой связной с ней секцией" -- Needs review
	L["Use this to adjust the bag scale."] = "Регулировка масштаба сумок."
	L["Use this to adjust the quality-based border opacity. 100% means fully opaque."] = "Используете ето для настройки, на основе качества, границ прозрачности. 100% означает полностью непрозрачный"
	L["Virtual stacks"] = "Виртуальные стопки"
	L["Virtual stacks display in one place items that actually spread over several bag slots."] = "Виртуальные стопки отображаютса в одном месте, предметы которые на самом деле распространяютса в нескольких сумачных слотаф."
	L["Virtual stack slots"] = "Виртуальное сложение слотов" -- Needs review
	L["When alt is held down"] = "Когда кнопка Alt нажата"
	L["When any modifier key is held down"] = "Когда какая-либо клавиша модификатора нажата"
	L["When ctrl is held down"] = "Когда кнопка Ctrl нажата"
	L["When shift is held down"] = "Когда кнопка Shift нажата"
end

for k, v in pairs(L) do
	if v == true then
		L[k] = k
	end
end
