-- Контейнер элементов: от него наследуются Tab, Group и колонки.
-- Методы элементов (Toggle, Slider, ...) добавляются в Elements/*.lua
local Container = {}
Container.__index = Container

function Container.new(window, tab, holder, scroller)
	return setmetatable({
		Window = window,
		Tab = tab, -- вкладка-владелец (для поиска и прокрутки)
		Holder = holder, -- Frame, куда кладутся карточки
		Scroller = scroller, -- ScrollingFrame вкладки (блокируется при перетаскивании)
		Elements = {},
		_n = 0,
	}, Container)
end

function Container:_nextOrder()
	self._n += 1
	return self._n
end

return Container
