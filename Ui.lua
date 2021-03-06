-- The main Ui code, I'm trying to seprate it to see if this makes it cleaner :>
-- Arkii

require "./libs/lib_lokii";
require "./data";

-- Varables
Ui = {}; -- Public object
Const =
{
	MAXLEVEL = 40,
	CURRENT_LEVEL_MINUS_RANGE = 5,
	SMALL_SCREEN_LIMIT = 1120,
    MAIN = Component.GetFrame("Main"),
    WINDOW = Component.GetWidget("Window"),
    MOVABLE_PARENT = Component.GetWidget("MovableParent"),
    CLOSE_BUTTON = Component.GetWidget("close"),
    FILTER_HEADERS = Component.GetWidget("FiltersHeaders"),
    GLOBAL_SETTINGS_HEADER = Component.GetWidget("GlobalSettingsHeader"),
    BUTTONS_HEADER = Component.GetWidget("ButtonsHeader"),
    INV_WEIGHT_TEXT = Component.GetWidget("weight_text"),
    FILTER_LIST_WIDGET = Component.GetWidget("FilterList"),
    FILTER_LIST_FOSTERING = Component.GetWidget("FilterList_Fostering"),
	ADD_FILTER_POPUP_PARENT = Component.GetWidget("AddFilterPopupParent"),
	PERCENT_POPUP_PARENT = Component.GetWidget("PercentPopupParent"),
	REVIEW_POPUP =  Component.GetFrame("ReviewPopup"),
    --REVIEW_POPUP_MOVEABLE =  Component.GetWidget("ReviewPopupMoveable"),
    --RP_CLOSE_BUTTON = Component.GetWidget("rp_close"),
    REVIEW_LIST_FOSTERING = Component.GetWidget("ReviewList_Fostering"),
    REVIEW_LIST_PARENT = Component.GetWidget("ReviewList"),
    TOOLTIP_POPUP = Component.GetWidget("ToolTipPopUp"),
	RP_RESIZE_PARENT = Component.GetWidget("RP_ResizableParent"),
	INCLUDE_ARCHTYPE = Component.GetWidget("includeArchtype"),
	FILTER_SETS = Component.GetWidget("filterSets"),
	FILTER_SET_REMOVE = Component.GetWidget("filterSetRemove"),
	PROFITS_CY = Component.GetWidget("cy_text"),
	PROFITS_RP = Component.GetWidget("rp_text"),
	PROFITS_LIST_FOSTER = Component.GetWidget("ProfitsList_Fostering"),
	PROFITS_LIST = Component.GetWidget("ProfitsList"),
	PROFIT_FOCUS = Component.GetWidget("ProfitFocus"),
	PROFIT_TOOLTIP = Component.GetWidget("ProfitToolTip"),
	REVIEW_LIST_COUNT = Component.GetWidget("review_list_count"),
	REVIEW_LIST_CHECKALL = Component.GetWidget("RL_CheckAll"),
	REVIEW_LIST_SALVAGE_SELECTED = Component.GetWidget("RP_SavlageSelected"),
	REVIEW_LIST_KEEP_SELECTED = Component.GetWidget("RP_KeepSelected"),
	ACTIVE_FOR_FRAME = Component.GetWidget("ActiveForThisFrame"),
	RESIZEABLE_PARENT = Component.GetWidget("ResizableParent"),
	GLOBAL_SETTINGS_HEADER_CONT = Component.GetWidget("GlobalSettingsHeaderCont"),
	BUTTONS_HEADER_CONT = Component.GetWidget("ButtonsHeaderCont"),
	FILTERS = Component.GetWidget("Filters"),
	BUTTONS_GROUP = Component.GetWidget("ButtonsGroup"),

	SND =
	{
		OPEN_POPUP = "Play_SFX_UI_TipPopUp",
		FILTER_ROLL = "",
		ERROR = "Play_SFX_UI_SIN_CooldownFail"
	},

	BUTTON_COLORS = 
	{
		DEFAULT_PLATE_COLOR = "#0E7192",
		DEFAULT_BLUE_COLOR = "#106288",
		DEFAULT_WHITE_COLOR = "#9C9C9C",
		DEFAULT_GREEN_COLOR = "#629E0A",
		DEFAULT_RED_COLOR = "#8E0909",
		DEFAULT_YELLOW_COLOR = "#FFFF00"		
	}
};

local Private = -- Private object, easier to keep track of important vars like this :>
{
    FilterHeaderButtons = nil,
    AddFilterButton = nil,
    TestFilterButton = nil,
    OpenReviewButton = nil,
    FilterList = nil,
    IsOddRow = false,
	AddFilterPopUp = {},
	PercentPopup = {},
    ReviewPopUp = {},
	ConsumablePopup = {},
	IsOddReviewRow = false,
	IncludeArchtypeCB = nil,
	InventoryButton = nil,
	InventoryButtonRL = nil,
	IsReviewListOpen = false,
	ProfitsList = nil,
	ProfitsListIdLookup = {},
	UiCallbacks = {},
	ReviewListSavlageSelected = nil,
	ReviewListSavlageKeep = nil,
	ReviewListIsTest = false,
	ReviewListCheckall = nil,
	FilterSets = nil,
	FilterSetRemove = nil,
	IsInSmallScreenMode = false
};

-- Public functions
function Ui.Init()
    MovablePanel.ConfigFrame({
		frame = Const.MAIN,
		MOVABLE_PARENT = Const.MOVABLE_PARENT,
		RESIZABLE_PARENT = Const.RESIZEABLE_PARENT,
		min_height = 420,
		min_width = 670,
		step_height = 1,
		step_width = 10,
		OnResize = Private.OnMainWindowRezise
	});

	Const.MAXLEVEL = #Game.GetProgressionUnlocks();

	InterfaceOptions.SetCallbackFunc(Private.UiOptionsCallback, Lokii.GetString("WINDOW_TITE"));
	Private.CreateUiOptions();

    Private.CreateWidgets();
	Private.CreateAddFilterPopup();
    Private.CreatePercentPopup();
    Private.CreateReviewPopUp();
	Private.CreateProfitsTootip();
	Private.CreateConsumablePopup();

    PanelManager.RegisterFrame(Const.MAIN, ToggleWindow, {show=false});
    Ui.Show(false);

    Lokii.ReplaceKeysOnFrame(Const.MAIN);
	Lokii.ReplaceKeysOnFrame(Const.REVIEW_POPUP);
end

function Ui.Show(show)
    Const.MAIN:Show(show);
    Component.SetInputMode(show and "cursor" or "none");

    if (show) then
    	PanelManager.OnShow(Const.MAIN)
    else
    	PanelManager.OnHide(Const.MAIN)
    end

    if (Private.IsReviewListOpen and not show) then
    	Ui.ShowReview(false);
    end
end

function Ui.ShowReview(show, isReview)
	if not Const.MAIN:IsVisible() then
		Component.SetInputMode(show and "cursor" or "none");
	end

	Const.REVIEW_POPUP:Show(show);
	Private.IsReviewListOpen = show;
	Private.ReviewListIsTest = isReview;
	Private.ReviewListCheckall:Enable(uiOpts.inventorySalvaging or not isReview);
	Private.ReviewListCheckall:SetCheck(false);
	Private.ReviewListSavlageSelected:Enable(uiOpts.inventorySalvaging or not isReview);
	Private.ReviewListSavlageKeep:Enable(not isReview);
end

function ToggleWindow(args)
	Ui.Show(args.show);
end

function Ui.SetInventoryWeight(inv)
    -- ToDo: Color code when close to limit?
    Const.INV_WEIGHT_TEXT:SetText(unicode.format("%i/%i (%i%%)", inv.current, inv.max, math.floor(inv.precent*100)));
end

function Ui.AddFilterRow(id, data)
    local row = Private.CreateFilterRow(id, data);

    if Private.IsOddRow then
        row:SetBGAlpha(0.2);
    else
        row:SetBGAlpha(0.4);
    end

    Private.IsOddRow = not Private.IsOddRow;
end

function Ui.ClearFilters()
	Private.FilterList:Reset();
end

function Ui.AddToReviewList(guid, sdbId, quanity, isReview)
	Private.AddToReviewUI(guid, sdbId, quanity, isReview);
end

function Ui.ClearReviewList()
	Private.ClearReviewUI();
end

function Ui.ReviewListSetCount(count)
	Const.REVIEW_LIST_COUNT:SetText(count);
end

function Ui.UpdateProfitsTootip(profitList)
	for id, val in pairs(profitList) do
		Private.AddToProfitsList(id, val);
	end

	Const.PROFITS_CY:SetText(_math.MakeReadable(profitList["10"] or 0));
	Const.PROFITS_RP:SetText(_math.MakeReadable(profitList["86154"] or 0));
end

function Ui.ShowDialog(args)
	Private.ShowDialog(args);
end

function Ui.ShowTextDialog(args)
	Private.ShowTextDialog(args);
end

function Ui.UpdateFilterSets(sets)
	Private.FilterSets:ClearItems();
	for i, data in pairs(sets) do
		Private.FilterSets:AddItemAndValue(data, data);
	end
	Private.FilterSets:AddItemAndValue(Lokii.GetString("NEW_FILTER_SET"), NEW_FILTER_SET_ID);
end

function Ui.SetActiveFilterSet(active, noSet)
	if active then
		Private.FilterSets:SetSelectedByValue(active);
		if not noSet then
			SetActiveFilterSet(active);
		end
	else
		Debug.Warn("active was nil! D:");
	end
end

--[[function AlignWidgetHorz(widgetarr, align, padding)
	local lastpos = (align == "left") and widgetarr[1]:GetDims(true).left.offset or widgetarr[1]:GetDims(true).right.offset;
	Print(tostring(widgetarr[1]:GetDims()));

	for i, widget in ipairs(widgetarr) do
		local width = widget:GetBounds().width;

		lastpos = lastpos + width + padding;
		widget:MoveTo(align..":"..lastpos..";", 0);
	end
end]]

-- Private functions
function Private.CreateWidgets()
    --
    Private.SetHeaderText(Const.GLOBAL_SETTINGS_HEADER, Lokii.GetString("GLOBAL_SETTINGS"));
    Private.SetHeaderText(Const.BUTTONS_HEADER, Lokii.GetString("ACTIONS"));

    -- Filter headers
    Private.FilterHeaderButtons =
    {
        FLT_TYPE = Private.CreateFilterButton(Const.FILTER_HEADERS:GetChild("type"), "FLT_TYPE"),
        FLT_FRAME = Private.CreateFilterButton(Const.FILTER_HEADERS:GetChild("frame"), "FLT_FRAME"),
        FLT_LEVEL_RANGE = Private.CreateFilterButton(Const.FILTER_HEADERS:GetChild("levelRange"), "FLT_LEVEL_RANGE"),
        FLT_COLOR = Private.CreateFilterButton(Const.FILTER_HEADERS:GetChild("color"), "FLT_COLOR"),
        FLT_WHEN = Private.CreateFilterButton(Const.FILTER_HEADERS:GetChild("when"), "FLT_WHEN"),
        FLT_ACTION = Private.CreateFilterButton(Const.FILTER_HEADERS:GetChild("action"), "FLT_ACTION")
    };

    Private.AddFilterButton = Component.CreateWidget('LibButton', Component.GetWidget("AddFilterButton")):GetChild("Button");
    Private.AddFilterButton:SetText(Lokii.GetString("ADD_FILTER"));
    --Private.AddFilterButton:Autosize("right");
	Private.AddFilterButton:BindEvent("OnSubmit", function()
		Private.SetAddFilterData(DEFAULT_FILTER_DATA);
		Private.OpenPopUp(Private.AddFilterPopUp.Window);
		System.PlaySound(Const.SND.OPEN_POPUP);
	end);

    Private.TestFilterButton = Component.CreateWidget('LibButton', Component.GetWidget("TestFilterButton")):GetChild("Button");
    Private.TestFilterButton:SetText(Lokii.GetString("TEST_FILTER"));
    --Private.TestFilterButton:Autosize("right");
	Private.TestFilterButton:BindEvent("OnSubmit", function()
		TestFilters();
	end);

	Private.OpenReviewButton = Component.CreateWidget('LibButton', Component.GetWidget("ReviewListButton")):GetChild("Button");
    Private.OpenReviewButton:SetText(Lokii.GetString("OPEN_REVIEW_LIST"));
    --Private.OpenReviewButton:Autosize("right");
	Private.OpenReviewButton:BindEvent("OnSubmit", function()
		LoadReviewList();
	end);

	--[[AlignWidgetHorz(
	{
		Private.OpenReviewButton:GetWidget(),
		Private.TestFilterButton:GetWidget(),
		Private.AddFilterButton:GetWidget()
	}, "left", 5);]]

    -- Filter list
    Private.FilterList = RowScroller.Create(Const.FILTER_LIST_WIDGET);
    Private.FilterList:SetSpacing(2);
    Private.FilterList:ShowSlider(true);

    -- Setup the close button
	Const.CLOSE_BUTTON:BindEvent("OnMouseDown", function()
		Ui.Show(false);
	end);
	local X = Const.CLOSE_BUTTON:GetChild("X");
	Const.CLOSE_BUTTON:BindEvent("OnMouseEnter", function()
		X:ParamTo("tint", Component.LookupColor("red"), 0.15);
		X:ParamTo("glow", "#30991111", 0.15);
	end);
	Const.CLOSE_BUTTON:BindEvent("OnMouseLeave", function()
		X:ParamTo("tint", Component.LookupColor("white"), 0.15);
		X:ParamTo("glow", "#00000000", 0.15);
	end);

	-- Item tooltip card
	Private.ItemCard = LIB_ITEMS.CreateToolTip(Const.TOOLTIP_POPUP);
	--Const.TOOLTIP_POPUP:SetDims("height:" .. Private.ItemCard.GetWidget():GetChild("List"):GetLength())

	-- Settings
	Private.IncludeArchtypeCB = Component.CreateWidget('LibCheckbox', Const.INCLUDE_ARCHTYPE):GetChild("Checkbox");
	Private.IncludeArchtypeCB:SetCheck(config.includeArchtype);
	Private.IncludeArchtypeCB:BindEvent("OnStateChanged", function()
		config.includeArchtype = Private.IncludeArchtypeCB:GetCheck();
		ConfigSaveSetting("includeArchtype");
	end);

	--Private.FilterSets = Component.CreateWidget('LibDropdown', Const.FILTER_SETS):GetChild("Dropdown");
	Private.FilterSets = DropDown.Create(Const.FILTER_SETS)
	Private.FilterSets:BindEvent("OnSelect", function()
		if not Private.FilterSets.wasSetSelectedByValue then
			local value = Private.FilterSets:GetValueByLabel(Private.FilterSets:GetSelected())
			SetActiveFilterSet(value)
		else
			Private.FilterSets.wasSetSelectedByValue = false
		end
	end);

	Private.FilterSetRemove = Component.CreateWidget('LibButton', Const.FILTER_SET_REMOVE):GetChild("Button");
	Private.FilterSetRemove:SetText("X");
	Private.FilterSetRemove:SetParam("tint", Const.BUTTON_COLORS.DEFAULT_RED_COLOR);
	Private.FilterSetRemove:BindEvent("OnSubmit", function()
		Private.ShowDialog(
		{
			body = Lokii.GetString("DELETE_FILTER_SET"):format(activeFilterSet or ""),
			onYes = DeleteFilterSet,
			onNo = function()

			end
		});
	end);

	Private.ActiveForThisFrame = Component.CreateWidget('LibButton', Const.ACTIVE_FOR_FRAME):GetChild("Button");
	Private.ActiveForThisFrame:BindEvent("OnSubmit", function() ToggleActiveForChar(Private.ActiveForThisFrame); end);

	-- Foster button into Inventory
	local InvButton = Component.CreateWidget('<Group dimensions="left:5; top:-33; width:80; height:26;" />', Const.REVIEW_LIST_FOSTERING);
	Private.InventoryButton = Component.CreateWidget('LibButton', InvButton):GetChild("Button");
	Private.InventoryButton:SetText(Lokii.GetString("WINDOW_TITE"));
	Component.FosterWidget(InvButton, "Inventory:main.{1}.{1}"); -- I <3 Fostering
	Private.InventoryButton:BindEvent("OnSubmit", function()
			Ui.Show(true);
		end);

	local InvButtonRL = Component.CreateWidget('<Group dimensions="left:88; top:-33; width:25; height:26;" />', Const.REVIEW_LIST_FOSTERING);
	Private.InventoryButtonRL = Component.CreateWidget('LibButton', InvButtonRL):GetChild("Button");
	Private.InventoryButtonRL:SetText(Lokii.GetString("RL"));
	Component.FosterWidget(InvButtonRL, "Inventory:main.{1}.{1}");
	Private.InventoryButtonRL:BindEvent("OnSubmit", function()
			LoadReviewList();
		end);
end

function Ui.UpdateActiveCharButton()
	if IsActiveForChar() then
		Private.ActiveForThisFrame:SetText(Lokii.GetString("DEACTIVATE_FOR_CHAR"), true);
		Private.ActiveForThisFrame:SetParam("tint", Const.BUTTON_COLORS.DEFAULT_RED_COLOR);
		Private.ActiveForThisFrame:Autosize("left", 0.25);
	else
		Private.ActiveForThisFrame:SetText(Lokii.GetString("ACTIVATE_FOR_CHAR"), true);
		Private.ActiveForThisFrame:SetParam("tint", Const.BUTTON_COLORS.DEFAULT_GREEN_COLOR);
		Private.ActiveForThisFrame:Autosize("left", 0.25);
	end
end

function Private.CreateFilterButton(hostWidget, key)
	local widget = Component.CreateWidget('FilterHeaderButton', hostWidget)
    local butt = { widget = widget, button = widget:GetChild("Button"), descending = true };

	butt.button:SetText(Lokii.GetString(key));

    butt.button:BindEvent("OnSubmit", function(args)
        butt.descending = not butt.descending;
        widget:GetChild("SortOrient.Arrow"):SetRegion(butt.descending and "down" or "up");
        Private.OnFiltersSortChanged(key, butt.descending);
		SortFilterList(key, butt.descending);
		Component.SaveSetting("FilterSortOrder", {key=key, order=butt.descending})
    end);

    butt.Reset = function()
        widget:GetChild("SortOrient.Arrow"):SetRegion("down");
        butt.descending = true;
    end

    return butt; -- hehe
end

function Private.OnFiltersSortChanged(key, descending)
    for i, data in pairs(Private.FilterHeaderButtons ) do
        if (i ~= key) then
            data.Reset();
        end
    end
end

function Private.SetHeaderText(widget, text)
    local textWidget = widget:GetChild("name");
    textWidget:SetText(text);

    local width = textWidget:GetTextDims().width + 14;
    widget:GetChild("textBG"):SetDims("center-x:_; top:_; height:_; width:"..width..";");
    textWidget:SetText(text);
end

function Private.EditFilter(row)
	Private.SetAddFilterData(FiltersData.filters[row.id]);
	Private.AddFilterPopUp.EditMode = true;
	Private.AddFilterPopUp.EditId = row.id;
    Private.AddFilterPopUp.AddButt:SetText(Lokii.GetString("SAVE_FILTER"));
	Private.OpenPopUp(Private.AddFilterPopUp.Window);
	System.PlaySound(Const.SND.OPEN_POPUP);
end

function Private.DeleteFilter(row)
	Private.ShowDialog(
	{
		body=Lokii.GetString("DELETE_FILTER_PROMPT"),
		onYes = function()
			DeleteFilter(row.id);
		end,
		onNo = function()

		end
	});
end

-- Filter Row Display Class
local FilterRowMT = {};
FilterRowMT.__index = FilterRowMT;

function Private.CreateFilterRow(id, data)
    local row = {};
    setmetatable(row, FilterRowMT);
    row.defaultBgAlpha = 0.4;
    row.widget = Component.CreateWidget("ListRow", Const.FILTER_LIST_FOSTERING);
    local content = row.widget:GetChild("content");
    row.id = id;

    Debug.Log("Add filter row Data: "..tostring(data))

	-- format data
	local formatedData = {};
	formatedData.type = Lokii.GetString(data.typeName);
	formatedData.frame = Lokii.GetString(data.frame);

	local levelTo = tonumber(data.levelTo)
	if levelTo <= 0 then
		levelTo = Private.FormatCurrentLevelMinus(levelTo)
	end

	formatedData.levelRange = unicode.format("%s %s %s %s", Lokii.GetString("FROM"), data.levelFrom, Lokii.GetString("TO"), levelTo);
	formatedData.color = Lokii.GetString(data.color);

	if (data.when == "INV_PCT_FULL") then
		formatedData.when = unicode.format(Lokii.GetString("INV_PCT_FULL_FMT"), math.floor(data.precentFull*100));
	else
		formatedData.when = Lokii.GetString(data.when);
	end

	formatedData.action = Lokii.GetString(data.action);

    Component.CreateWidget("RowField", content:GetChild("type")):GetChild("text"):SetText(formatedData.type);
    Component.CreateWidget("RowField", content:GetChild("frame")):GetChild("text"):SetText(formatedData.frame);
    Component.CreateWidget("RowField", content:GetChild("levelRange")):GetChild("text"):SetText(formatedData.levelRange);
    Component.CreateWidget("RowField", content:GetChild("color")):GetChild("text"):SetText(formatedData.color);
    Component.CreateWidget("RowField", content:GetChild("when")):GetChild("text"):SetText(formatedData.when);
    Component.CreateWidget("RowField", content:GetChild("action")):GetChild("text"):SetText(formatedData.action);

    local focus = row.widget:GetChild("focusBox");
    row.bg = row.widget:GetChild("bg");
    focus:BindEvent("OnMouseEnter", function()
		row.bg:ParamTo("tint", Component.LookupColor("RowHover"), 0.15);
        row.bg:ParamTo("alpha", 0.3, 0.15);
		--System.PlaySound(Const.SND.FILTER_ROLL);
	end);
	focus:BindEvent("OnMouseLeave", function()
		row.bg:ParamTo("tint", Component.LookupColor("RowDefault"), 0.15);
        row.bg:ParamTo("alpha", row.defaultBgAlpha, 0.15);
	end);

    -- Setup the context menu
	local OpenContextMenu = function()
		row.ContextMenu = ContextualMenu.Create()
		row.ContextMenu:AddLabel({label=Lokii.GetString("FILTER_OPTIONS")})
		row.ContextMenu:AddButton({label=Lokii.GetString("EDIT_FILTER")}, function(args) Private.EditFilter(row); end)
		row.ContextMenu:AddButton({label=Lokii.GetString("DELETE_FILTER")}, function(args) Private.DeleteFilter(row); end)
		row.ContextMenu:Show()
	end
    focus:BindEvent("OnRightMouse", OpenContextMenu);
	focus:BindEvent("OnMouseDown",  OpenContextMenu);

	row.ListRef = Private.FilterList:AddRow(row.widget);

    return row;
end

function FilterRowMT:SetBGAlpha(alpha)
    self.defaultBgAlpha = alpha;
    self.bg:ParamTo("alpha", alpha, 0);
end

--------------------------------
-- Add filter popup
--------------------------------

function Private.CreateAddFilterPopup()
	Private.AddFilterPopUp.Window = RoundedPopupWindow.Create(Const.ADD_FILTER_POPUP_PARENT, nil);
	local window = Private.AddFilterPopUp.Window;
	window:SetTitle(Lokii.GetString("ADD_FILTER_HEADER"));
	window:SetDims("dock:fill;");
	window:EnableClose(true, function () end);

	Private.AddFilterPopUp.Body = Component.CreateWidget("AddFilterBody", window:GetBody());
	local body = Private.AddFilterPopUp.Body;

	-- headers
	local header = body:GetChild("cont"):GetChild("header");
	Component.CreateWidget("AddFilterHeader", header:GetChild("type")):GetChild("text"):SetText(Lokii.GetString("FLT_TYPE"));
    Component.CreateWidget("AddFilterHeader", header:GetChild("frame")):GetChild("text"):SetText(Lokii.GetString("FLT_FRAME"));
    Component.CreateWidget("AddFilterHeader", header:GetChild("levelRange")):GetChild("text"):SetText(Lokii.GetString("FLT_LEVEL_RANGE"));
    Component.CreateWidget("AddFilterHeader", header:GetChild("color")):GetChild("text"):SetText(Lokii.GetString("FLT_COLOR"));
	Component.CreateWidget("AddFilterHeader", header:GetChild("when")):GetChild("text"):SetText(Lokii.GetString("FLT_WHEN"));
    Component.CreateWidget("AddFilterHeader", header:GetChild("action")):GetChild("text"):SetText(Lokii.GetString("FLT_ACTION"));

	local cont = body:GetChild("cont"):GetChild("cont");
	Private.AddFilterPopUp.DD_Type = DropDown.Create(cont:GetChild("type"));
	for id, data in pairs(GetDataSorted(DD_TYPES)) do
        Private.AddFilterPopUp.DD_Type:AddItemAndValue(Lokii.GetString(data.id), data.id);
    end

	Private.AddFilterPopUp.DD_Frame = DropDown.Create(cont:GetChild("frame"));
	for id, data in pairs(GetDataSorted(DD_FRAMES)) do
        Private.AddFilterPopUp.DD_Frame:AddItemAndValue(Lokii.GetString(data.id), data.id);
    end

	local levelRange = Component.CreateWidget("EnterLevelRange", cont:GetChild("levelRange"));
	Private.AddFilterPopUp.DD_FromLevel = DropDown.Create(levelRange:GetChild("{1}.dropDown1"));
	Private.AddFilterPopUp.DD_ToLevel = DropDown.Create(levelRange:GetChild("{1}.{1}.{1}.dropDown2"));

	for i = 1, Const.MAXLEVEL, 1 do
		Private.AddFilterPopUp.DD_FromLevel:AddItemAndValue(tostring(i), tostring(i));
		Private.AddFilterPopUp.DD_ToLevel:AddItemAndValue(tostring(i), tostring(i));
	end

	-- The players current level - the value
	for i = 0, Const.CURRENT_LEVEL_MINUS_RANGE, 1 do
		local val = -i
		Private.AddFilterPopUp.DD_ToLevel:AddItemAndValue(Private.FormatCurrentLevelMinus(val), val);
	end

	Private.AddFilterPopUp.DD_Color = DropDown.Create(cont:GetChild("color"));
	for id, data in pairs(GetDataSorted(DD_COLORS)) do
        Private.AddFilterPopUp.DD_Color:AddItemAndValue(Lokii.GetString(data.id), data.id);
    end
	Private.AddFilterPopUp.DD_Color:SetSelectedByValue("WHITE");

	Private.AddFilterPopUp.DD_When = DropDown.Create(cont:GetChild("when"));
	for id, data in pairs(DD_WHEN) do
        Private.AddFilterPopUp.DD_When:AddItemAndValue(Lokii.GetString(data), data);
    end

	Private.AddFilterPopUp.DD_When:BindEvent("OnSelect", function ()
		local selected = Private.AddFilterPopUp.DD_When:GetValueByLabel(Private.AddFilterPopUp.DD_When:GetSelected());
		if (selected == "INV_PCT_FULL") then
			Private.PercentPopup.SetPercent(0.50);
			Private.OpenPopUp(Private.PercentPopup.Window);
			Private.StylePopUp(Private.PercentPopup.Window);
			Private.PercentPopup.Window:GetBody():GetParent():GetParent():SetDims("height:130; bottom:100%; width:350; center-y:50%;");
			System.PlaySound(Const.SND.OPEN_POPUP);
		end
	end);

	Private.AddFilterPopUp.DD_Action = DropDown.Create(cont:GetChild("action"));
	for id, data in pairs(DD_ACTIONS) do
        Private.AddFilterPopUp.DD_Action:AddItemAndValue(Lokii.GetString(data), data);
    end

	Private.AddFilterPopUp.AddButt = Component.CreateWidget('LibButton', body:GetChild("AddButt")):GetChild("Button");
    Private.AddFilterPopUp.AddButt:SetText(Lokii.GetString("ADD_FILTER"));
    Private.AddFilterPopUp.AddButt:BindEvent("OnSubmit", function()
		Private.PercentPopup.Window:Close();
		window:Close();

		if (Private.AddFilterPopUp.EditMode == true) then
			EditFilter(Private.AddFilterPopUp.EditId, Private.GetAddFilterData());
			Private.AddFilterPopUp.EditMode = false;
		else
			CreateNewFilter(Private.GetAddFilterData());
		end
	end);

	-- Grey out unneed options
	Private.AddFilterPopUp.DD_Type:BindEvent("OnSelect", function (args)
		local selected = Private.AddFilterPopUp.DD_When:GetValueByLabel(Private.AddFilterPopUp.DD_When:GetSelected());
		local selectedType = Private.AddFilterPopUp.DD_Type:GetValueByLabel(Private.AddFilterPopUp.DD_Type:GetSelected());

		local skips = DD_TYPES[selectedType].skips;
		if skips.skipFrameCheck  then Private.AddFilterPopUp.DD_Frame:Disable(true); else Private.AddFilterPopUp.DD_Frame:Enable(true); end
		if skips.skipRarityCheck then Private.AddFilterPopUp.DD_Color:Disable(true); else Private.AddFilterPopUp.DD_Color:Enable(true); end

		if skips.skipRarityCheck then
			Private.AddFilterPopUp.DD_FromLevel:Disable(true);
			Private.AddFilterPopUp.DD_ToLevel:Disable(true);
		else
			Private.AddFilterPopUp.DD_FromLevel:Enable(true);
			Private.AddFilterPopUp.DD_ToLevel:Enable(true);
		end

		if selected == "CONSUMABLE" then
			Private.OpenPopUp(Private.ConsumablePopup.Window);
		end
	end);

	window:Close();

	-- Adjsut the style a little
	Private.StylePopUp(Private.AddFilterPopUp.Window);
end

function Private.GetAddFilterData()
	local data =
	{
		typeName = Private.AddFilterPopUp.DD_Type:GetValueByLabel(Private.AddFilterPopUp.DD_Type:GetSelected()),
		frame = Private.AddFilterPopUp.DD_Frame:GetValueByLabel(Private.AddFilterPopUp.DD_Frame:GetSelected()),
		levelFrom = Private.AddFilterPopUp.DD_FromLevel:GetValueByLabel(Private.AddFilterPopUp.DD_FromLevel:GetSelected()),
		levelTo = Private.AddFilterPopUp.DD_ToLevel:GetValueByLabel(Private.AddFilterPopUp.DD_ToLevel:GetSelected()),
		color = Private.AddFilterPopUp.DD_Color:GetValueByLabel(Private.AddFilterPopUp.DD_Color:GetSelected()),
		when = Private.AddFilterPopUp.DD_When:GetValueByLabel(Private.AddFilterPopUp.DD_When:GetSelected()),
		action = Private.AddFilterPopUp.DD_Action:GetValueByLabel(Private.AddFilterPopUp.DD_Action:GetSelected()),
		precentFull = Private.PercentPopup.GetPercent()
	};

	Debug.Log("Private.GetAddFilterData")
	Debug.Divider()
	Debug.Log(tostring(data))
	Debug.Divider()

	return data;
end

function Private.SetAddFilterData(data)
	Private.AddFilterPopUp.DD_Type:SetSelectedByValue(data.typeName);
	Private.AddFilterPopUp.DD_Frame:SetSelectedByValue(data.frame);
	Private.AddFilterPopUp.DD_FromLevel:SetSelectedByValue(data.levelFrom);
	Private.AddFilterPopUp.DD_ToLevel:SetSelectedByValue(data.levelTo);
	Private.AddFilterPopUp.DD_Color:SetSelectedByValue(data.color);
	Private.AddFilterPopUp.DD_When:SetSelectedByValue(data.when);
	Private.AddFilterPopUp.DD_Action:SetSelectedByValue(data.action);
	Private.PercentPopup.SetPercent(data.precentFull);
end

function Private.CreatePercentPopup()
	Private.PercentPopup.Percent = 0;

	Private.PercentPopup.Window = RoundedPopupWindow.Create(Private.AddFilterPopUp.Window:GetBody():GetParent(), nil);
	local window = Private.PercentPopup.Window;
	window:SetTitle(Lokii.GetString("INV_PCT_FULL"));
	window:SetDims("dock:fill;");
	window:EnableClose(true, function () end);

	Private.PercentPopup.Body = Component.CreateWidget("PercentPopUp", window:GetBody());
	local body = Private.PercentPopup.Body;

	local controls = body:GetChild("Controls");
	local textInput = controls:GetChild("InputGroup"):GetChild("TextInput");
	textInput:SetText("0");
	Private.PercentPopup.Slider = Component.CreateWidget('<Adjuster dimensions="dock:fill;" style="tabbable:true; scrollsteps:101; horizontal:true;"/>', controls:GetChild("Slider"));
	--[[Private.PercentPopup.Slider:SetSteps(101);
	Private.PercentPopup.Slider:SetScrollSteps(1);]]
	Private.PercentPopup.Slider:BindEvent("OnStateChanged", function(arg)
		local pct = math.floor(Private.PercentPopup.Slider:GetPercent()*100);
		textInput:SetText(tostring(pct));
		Private.PercentPopup.Percent = Private.PercentPopup.Slider:GetPercent();
	end);

	textInput:BindEvent("OnTextChange", function(arg)
		local pct = tonumber(textInput:GetText()/100);
		Private.PercentPopup.Slider:SetPercent(pct);
		Private.PercentPopup.Percent = pct;
	end);

	local OkButt = Component.CreateWidget('LibButton', body:GetChild("OkButt")):GetChild("Button");
	OkButt:SetText(Lokii.GetString("OK"));
	OkButt:BindEvent("OnSubmit", function()
		window:Close(false);
	end);

	Private.PercentPopup.SetPercent = function(p)
		Private.PercentPopup.Percent = p;
		textInput:SetText(tostring(math.floor(p*100)));
		Private.PercentPopup.Slider:SetPercent(p);
	end;

	Private.PercentPopup.GetPercent = function(p)
		Private.PercentPopup.Percent = Private.PercentPopup.Slider:GetPercent();
		return Private.PercentPopup.Percent;
	end;

	window:Close(false);
	Private.StylePopUp(Private.PercentPopup.Window);
end

function Private.CreateConsumablePopup()
	Private.ConsumablePopup.Window = RoundedPopupWindow.Create(Private.AddFilterPopUp.Window:GetBody():GetParent(), nil);
	local window = Private.ConsumablePopup.Window;
	window:SetTitle(Lokii.GetString("INV_PCT_FULL"));
	window:SetDims("dock:fill;");
	window:EnableClose(true, function () end);

	window:Close(false);
	Private.StylePopUp(Private.ConsumablePopup.Window);
end

-- Review PopUP
function Private.CreateReviewPopUp()
    Private.ReviewList = RowScroller.Create(Const.REVIEW_LIST_PARENT);
    Private.ReviewList:SetSpacing(2);
    Private.ReviewList:ShowSlider(true);
    Const.REVIEW_POPUP:SetTitle("Yay")

    --[[MovablePanel.ConfigFrame({
        frame = Const.REVIEW_POPUP,
        MOVABLE_PARENT = Const.REVIEW_POPUP_MOVEABLE,
		RESIZABLE_PARENT = Const.RP_RESIZE_PARENT,
		min_height = 420,
		min_width = 450,
		step_height = 1,
		step_width = 10,
		OnResize = Private.OnReviewWindowRezise
    });

    -- Setup the clsoe button
    Const.RP_CLOSE_BUTTON:BindEvent("OnMouseDown", function()
        Const.REVIEW_POPUP:Show(false);
    end);
    local X = Const.RP_CLOSE_BUTTON:GetChild("X");
    Const.RP_CLOSE_BUTTON:BindEvent("OnMouseEnter", function()
        X:ParamTo("tint", Component.LookupColor("red"), 0.15);
        X:ParamTo("glow", "#30991111", 0.15);
    end);
    Const.RP_CLOSE_BUTTON:BindEvent("OnMouseLeave", function()
        X:ParamTo("tint", Component.LookupColor("white"), 0.15);
        X:ParamTo("glow", "#00000000", 0.15);
    end);]]

	Private.ReviewListCheckall = Component.CreateWidget('LibCheckbox', Const.REVIEW_LIST_CHECKALL):GetChild("Checkbox");
	Private.ReviewListCheckall:BindEvent("OnStateChanged", function()
		if (not Private.ReviewListCheckall_IngoreStateChange) then
			for idx=1, Private.ReviewList:GetRowCount(), 1 do
				Private.ReviewList:GetRow(idx).checkBox:SetCheck(Private.ReviewListCheckall:GetCheck());
			end
		end
	end);

	Private.ReviewListSavlageSelected = Component.CreateWidget('LibButton', Const.REVIEW_LIST_SALVAGE_SELECTED):GetChild("Button");
    Private.ReviewListSavlageSelected:SetText(Lokii.GetString("SAVLVAGE_SELCECTED"));
	Private.ReviewListSavlageSelected:BindEvent("OnSubmit", function()
		SalvageSelected(Private.ReviewListIsTest);
	end);

	Private.ReviewListSavlageKeep = Component.CreateWidget('LibButton', Const.REVIEW_LIST_KEEP_SELECTED):GetChild("Button");
    Private.ReviewListSavlageKeep:SetText(Lokii.GetString("KEEP_SELECTED"));
	Private.ReviewListSavlageKeep:BindEvent("OnSubmit", function()
		KeepSelected();
	end);
end

function Private.OnReviewWindowRezise()
	Private.ReviewList:UpdateSize();
end

-- aka Choob mode :3
function Private.OnMainWindowRezise()
	local dims = Const.MAIN:GetBounds()
	local width = dims.width

	local isSmall = false
	if width < Const.SMALL_SCREEN_LIMIT then
		isSmall = true
	elseif width > Const.SMALL_SCREEN_LIMIT then
		isSmall = false
	end

	if isSmall and not Private.IsInSmallScreenMode then
		Const.GLOBAL_SETTINGS_HEADER_CONT:MoveTo("left:_; top:_; height:_; width:100%;", 0.5)
		Const.BUTTONS_HEADER_CONT:MoveTo("left:0; top:62; height:_; width:100%;", 0.5)
		Const.FILTERS:MoveTo("left:0; top:124; height:100%; width:100%", 0.5)
		Const.BUTTONS_GROUP:MoveTo("left:5; top:_; height:_; width:_;", 0.5)
		Debug.Log("Entered small mode")
	elseif not isSmall and Private.IsInSmallScreenMode then
		Const.GLOBAL_SETTINGS_HEADER_CONT:MoveTo("left:_; top:_; height:_; width:60%-1;", 0.5)
		Const.BUTTONS_HEADER_CONT:MoveTo("left:60%+1; top:0; height:_; width:40%;", 0.5)
		Const.FILTERS:MoveTo("left:0; top:62; height:100%; width:100%", 0.5)
		Const.BUTTONS_GROUP:MoveTo("right:100%-10; top:_; height:_; width:_;", 0.5)
		Debug.Log("Entered large mode")
	end

	Private.IsInSmallScreenMode = isSmall
end

function Private.OpenReviewPopUp()
    Const.REVIEW_POPUP:Show(true);
end

function Private.AddToReviewUI(guid, sdbId, quanity, isReview)
	local itemInfo = (guid ~= nil) and Player.GetItemInfo(guid) or Game.GetItemInfoByType(sdbId);
    local widget = Component.CreateWidget("ReviewLine", Const.REVIEW_LIST_FOSTERING);
    local row = Private.ReviewList:AddRow(widget);
	local alpha = 0.2;

	local bg = widget:GetChild("bg");
	if Private.IsOddReviewRow then
		alpha = 0.2;
    else
		alpha = 0.4
    end
	bg:ParamTo("alpha", 0.4, 0);
	Private.IsOddReviewRow = not Private.IsOddReviewRow;

	local focus = widget:GetChild("focusBox");
	focus:BindEvent("OnMouseEnter", function()
		if (itemInfo.rarity) then
			Private.ItemCard:DisplayInfo(itemInfo);
			Private.ItemCard:DisplayPaperdoll(true);
			Const.TOOLTIP_POPUP:SetDims("left_; top:_; width:_; height:" .. Private.ItemCard:GetBounds().height .. ";");
			Tooltip.Show(Private.ItemCard:GetWidget(), { delay = 0.7 });
		end

		bg:ParamTo("tint", Component.LookupColor("RowHover"), 0.15);
        bg:ParamTo("alpha", 0.3, 0.15);

		--System.PlaySound(Const.SND.FILTER_ROLL);
	end);

	focus:BindEvent("OnMouseLeave", function()
		Tooltip.Show();
		bg:ParamTo("tint", Component.LookupColor("RowDefault"), 0.15);
        bg:ParamTo("alpha", alpha, 0.15);
        --Paperdoll.Release();
	end);

	focus:BindEvent("OnMouseDown", function()
    	row.checkBox:SetCheck(not row.checkBox:GetCheck() and (uiOpts.inventorySalvaging or not isReview));
    end);

	widget:GetChild("icon"):SetIcon(itemInfo.web_icon_id)

	local level = 0;
	if (itemInfo.required_level == nil or itemInfo.required_level == 0) then
		level = "-";
	else
		level = itemInfo.required_level;
	end
	widget:GetChild("level"):SetText(level);

	local TF = LIB_ITEMS.GetNameTextFormat(itemInfo, {rarity = itemInfo.rarity});
	TF:AppendText(unicode.format(" x %i", quanity))
	TF:ApplyTo(widget:GetChild("text"));

	--bg:SetParam("tint", Component.LookupColor(LIB_ITEMS.GetItemColor(itemInfo)));

	row.checkBox = Component.CreateWidget("libCheckbox", widget:GetChild("checkbox")):GetChild("Checkbox");
	row.checkBox:Enable(uiOpts.inventorySalvaging or not isReview);
	row.checkBox:BindEvent("OnStateChanged", function()
		if (uiOpts.inventorySalvaging or not isReview) then
			if (Private.ReviewListCheckall:GetCheck() and not row.checkBox:GetCheck()) then
				Private.ReviewListCheckall_IngoreStateChange = true;
				Private.ReviewListCheckall:SetCheck(false);
				Private.ReviewListCheckall_IngoreStateChange = false;
			end

			ReviewQueueFinilise(row.checkBox:GetCheck(), guid, sdbId, quanity);
		end
	end);
end

function Private.ClearReviewUI()
	Private.ReviewList:Reset();
end

function Private.CreateProfitsTootip()
	Private.ProfitsList = RowScroller.Create(Const.PROFITS_LIST);
    Private.ProfitsList:SetSpacing(2);
    Private.ProfitsList:ShowSlider(false);

   Const.PROFIT_FOCUS:BindEvent("OnMouseEnter", function()
		local tt_bounds = Private.ProfitsList:GetContentSize()
		Tooltip.Show(Const.PROFIT_TOOLTIP, {width=Const.PROFIT_TOOLTIP:GetBounds().width, height=tt_bounds.height + 32, frame_color="#DADADA"})
   end);

   Const.PROFIT_FOCUS:BindEvent("OnMouseLeave", function()
		Tooltip.Show(false);
   end);
end

function Private.AddToProfitsList(sdbId, quanity)
	if (not Private.ProfitsListIdLookup[sdbId]) then
		local info = Game.GetItemInfoByType(sdbId);

		local widget = Component.CreateWidget("ProfitLine", Const.REVIEW_LIST_FOSTERING);
		widget:SetDims("height:22; width:100%; top:0; left:0")
		widget:GetChild("Name"):SetText(info.name);
		widget:GetChild("Quantity"):SetText(_math.MakeReadable(quanity));

		if info.web_icon_id then
			widget:GetChild("icon"):SetIcon(info.web_icon_id);
		else
			Debug.Warn("info.web_icon was nil!")
		end

		local name_bounds = widget:GetChild("Name"):GetTextDims().width
		local quantity_bounds = widget:GetChild("Quantity"):GetTextDims().width

		widget:GetChild("dash_lines"):SetMaskDims("left:" .. (name_bounds+15) .. "; right:100%-" .. (quantity_bounds+31));

   		Private.ProfitsListIdLookup[sdbId] = widget;
   		Private.ProfitsList:AddRow(widget);
	else
		Private.ProfitsListIdLookup[sdbId]:GetChild("Quantity"):SetText(_math.MakeReadable(quanity));
	end
end

-- {body="", onYes=function, onNo=function}
function Private.ShowDialog(args)
	SimpleDialog.Display(args.body);
	SimpleDialog.SetTitle(Lokii.GetString("CONFIRM"));

	SimpleDialog.AddOption(Lokii.GetString("ABORT"), function()
		if args.onNo then args.onNo(); end
		SimpleDialog.Hide();
	end, {color = Const.BUTTON_COLORS.DEFAULT_WHITE_COLOR});

	SimpleDialog.AddOption(Lokii.GetString("ARE_YOU_SURE"), function()
		if args.onYes then args.onYes(); end
		SimpleDialog.Hide();
	end, {color = Const.BUTTON_COLORS.DEFAULT_GREEN_COLOR});
	System.PlaySound(Const.SND.OPEN_POPUP);

end

function Private.ShowTextDialog(args)
	local widget = Component.CreateWidget("TextPopup", Const.REVIEW_LIST_FOSTERING);
	local textInput = widget:GetChild("Text.InputGroup.TextInput");
	textInput:SetFocus();
	SimpleDialog.Display(widget);
	SimpleDialog.SetTitle(Lokii.GetString("FILTER_SET_NAME"));

	SimpleDialog.AddOption(Lokii.GetString("ABORT"), function()
		if args.onNo then args.onNo(); end
		SimpleDialog.Hide();
	end, {color = Const.BUTTON_COLORS.DEFAULT_WHITE_COLOR});

	SimpleDialog.AddOption(Lokii.GetString("ARE_YOU_SURE"), function()
		if args.onYes then args.onYes(textInput:GetText()); end
		SimpleDialog.Hide();
	end, {color = Const.BUTTON_COLORS.DEFAULT_GREEN_COLOR});

	SimpleDialog.SetDims("center-x:50%; center-y:50%; width:300; height:150;");
	System.PlaySound(Const.SND.OPEN_POPUP);
end

-- TODO: Make a lib for these style of popups
function Private.StylePopUp(popUp)
	popUp:TintBack("#1B1E1F");
	popUp:GetHeader():GetParent():ParamTo("tint", "#2b333a", 0, 0);
end

function Private.OpenPopUp(popUp)
	popUp:Open();
	popUp:GetBody():GetParent():GetParent():SetDims("height:200; center-x:50%; width:80%; center-y:50%; relative:screen;");
	popUp:GetHeader():GetParent():SetDims("height:40; left:_; right:_; top:-6");
end

function Private.CreateUiOptions()
	InterfaceOptions.AddCheckBox({id="enableDebug", label=Lokii.GetString("ENABLE_DEBUG"), default=uiOpts.enableDebug});
	InterfaceOptions.AddCheckBox({id="enableDebugTimes", label=Lokii.GetString("ENABLE_DEBUG_TIMES"), default=uiOpts.debugLogTimes});

	InterfaceOptions.AddChoiceMenu({id="locale", label=Lokii.GetString("LOCALE_OVERRIDE"), default=uiOpts.localeOverride});
	for i, value in ipairs(LOCALES) do
		local val = tostring(value)
		InterfaceOptions.AddChoiceEntry({menuId="locale", label=Lokii.GetString(val), val=val});
	end

	InterfaceOptions.AddCheckBox({id="printSummary", label=Lokii.GetString("PRINT_SUMMARY"), tooltip=Lokii.GetString("PRINT_SUMMARY_TT"), default=uiOpts.printSummary});
	InterfaceOptions.AddCheckBox({id="processLoot", label=Lokii.GetString("PROCESS_LOOT"), tooltip=Lokii.GetString("PROCESS_LOOT_TT"), default=uiOpts.processLoot});
	InterfaceOptions.AddCheckBox({id="processRewards", label=Lokii.GetString("PROCESS_REWARDS"), tooltip=Lokii.GetString("PROCESS_REWARDS_TT"), default=uiOpts.processRewards});

	InterfaceOptions.AddChoiceMenu({id="printSummaryChan", label=Lokii.GetString("PRINT_SUMMARY_CHAN"), default=uiOpts.printSummaryChan});
	InterfaceOptions.AddChoiceEntry({menuId="printSummaryChan", label_key="CHAT_LOOT_NAME", val="loot"});
	InterfaceOptions.AddChoiceEntry({menuId="printSummaryChan", label_key="CHAT_SYSTEM_NAME", val="system"});

	InterfaceOptions.AddCheckBox({id="inventorySalvaging", label=Lokii.GetString("ENABLE_INV_FILTERING"), tooltip=Lokii.GetString("ENABLE_INV_FILTERING_TT"), default=uiOpts.inventorySalvaging});

	InterfaceOptions.AddCheckBox({id="reportRewards", label=Lokii.GetString("REPORT_REWARDS"), tooltip=Lokii.GetString("REPORT_REWARDS_TT"), default=uiOpts.reportRewards});

	InterfaceOptions.AddCheckBox({id="salvageInNullZones", label=Lokii.GetString("NULL_ZONES"), tooltip=Lokii.GetString("NULL_ZONES_TT"), default=uiOpts.salvageInNullZones});
	InterfaceOptions.StartGroup({id="zonesGrp", label=Lokii.GetString("ACTIVE_ZONE_TITLE"), checkbox=true, default=true});

	for _,val in pairs(GenrateDetailedZoneList()) do
		InterfaceOptions.AddCheckBox({id="zone_"..val.zone_id, label=val.title, default=true});
	end
	InterfaceOptions.StopGroup()
end

-- A userinterface option has changed
function Private.UiOptionsCallback(id, val)
	if id:find("zone_") then
		uiOpts.activeZones[id:gsub("zone_", "")] = val;
	else
		local func = Private.UiCallbacks[id];
		if (func) then
			func(val);
		end
	end
end

function Private.UiCallbacks.enableDebug(val)
	uiOpts.enableDebug = val;
	Debug.EnableLogging(--[[IsUserAuthor() or ]]uiOpts.enableDebug);
end

function Private.UiCallbacks.printSummary(val)
	uiOpts.printSummary = val;
	InterfaceOptions.EnableOption("printSummaryChan", val);
end

function Private.UiCallbacks.printSummaryChan(val)
	uiOpts.printSummaryChan = val;
end

function Private.UiCallbacks.reportRewards(val)
	uiOpts.reportRewards = val;
end

function Private.UiCallbacks.processLoot(val)
	uiOpts.processLoot = val;
end

function Private.UiCallbacks.processRewards(val)
	uiOpts.processRewards = val;
end

function Private.UiCallbacks.inventorySalvaging(val)
	uiOpts.inventorySalvaging = val;
end

function Private.UiCallbacks.salvageInNullZones(val)
	uiOpts.salvageInNullZones = val;
end

function Private.UiCallbacks.enableDebugTimes(val)
	uiOpts.debugLogTimes = val;
end

function Private.UiCallbacks.locale(val)
	if val == "SYSTEM_DEFAULT" then
		Lokii.SetToLocale()
	elseif val then
		Lokii.SetLang(val)
	end

	if Component.GetSetting("option-listmenu:locale") ~= val then
		Print(Lokii.GetString("RELOADUI_NEEDED"))
	end

	uiOpts.localeOverride = val
end

function Private.FormatCurrentLevelMinus(level)
	if level == 0 then
		return Lokii.GetString("CURRENT")
	else
		return unicode.format(Lokii.GetString("CURRENT").." %i", level)
	end
end