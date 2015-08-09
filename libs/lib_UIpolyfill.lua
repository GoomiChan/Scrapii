-- Store values with dropdown keys
-- Arkii

if DropDown then
	return nil
end
local DropDownCount = 1
local DropDownLookups = {}
DropDown = {}

function DropDown.Create(parent)
	local widget = Component.CreateWidget('LibDropdown', parent):GetChild("Dropdown");
	local dropdown = 
	{
		widget = widget,
		id = DropDownCount,
		numItems = 0
	}

	-- Forward the dropdown funcs
	for name, func in pairs(getmetatable(widget).__index) do
		--log(name)
		if name ~= "Clear" then
			dropdown[name] = function(...) return func(widget, select(2, unpack(arg))) end
		end
	end

	setmetatable(dropdown, {__index = function(t,key) return DropDown[key] end});
	table.insert(DropDownLookups, {}) 

	DropDownCount = DropDownCount + 1
	return dropdown
end

function DropDown.AddItemAndValue(self, label, value)
	self.numItems = self.numItems + 1
	DropDownLookups[self.id][label] = {value = value, index = self.numItems}
	self.widget:AddItem(label)
end

function DropDown.GetValueByLabel(self, label)
	local value = DropDownLookups[self.id][label].value
	return value
end

function DropDown.GetindexByLabel(self, label)
	local index = DropDownLookups[self.id][label].index
	return index
end

function DropDown.SetSelectedByValue(self, value)
	local index = 0
	for i, val in ipairs(DropDownLookups[self.id]) do
		if val.value == value then
			index = val.index
		end
	end

	if index ~= 0 then
		self.widget:SetSelectedByIndex(index)
	end
end

function DropDown.Clear(self)
	log("DropDown.Clear")
	self.numItems = 0
	DropDownLookups[self.id] = {}
	self.widget:Clear()
end