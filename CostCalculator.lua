--Car cost calculator script for luaExporter by Endfinity

----------------------------------
--These parameters can be changed

local Modifiers = {
	TrimEngineeringTime = 1.0,
	EngineEngineeringTime = 1.0
}

local WorkingDaysInAMonth = 27

local CarFactorySettings = {
	Employees = 200,
	EmployeeHourlyRate = 10,
	WorkingHoursPerShift = 8,
	AutomationAndToolingCoef = 1.2,
	
	Shifts = 2,
	FactoryUpkeepPerMonth = 200000,
	
	ProductionEfficiency = 1.0
}

local EngineFactorySettings = {
	Employees = 200,
	EmployeeHourlyRate = 10,
	WorkingHoursPerShift = 8,
	AutomationAndToolingCoef = 1.2,
	
	Shifts = 2,
	FactoryUpkeepPerMonth = 200000,
	
	ProductionEfficiency = 1.0
}

local CarProjectSettings = {
	EngineeringTimeFunding = 1.0,
	ProductionOptimization = 1.0,
	BreakevenMonths = 60
}

local EngineProjectSettings = {
	EngineeringTimeFunding = 1.0,
	ProductionOptimization = 1.0,
	BreakevenMonths = 60
}

local PriceMargin = 0.2 -- remove or set to nil if not needed

local OutputTemplate =
[[
Total cost per car: $$totalCost$
Total project engineering time: $totalET$ months
Total engineering costs: $$totalEC$ (included into cost per car)

Maximum produced cars per shift: $maxCarsPerShift$ units
Maximum produced cars per month: $maxCarsPerMonth$ units

Cost per trim: $$trimCost$
Trim engineering time: $trimET$ months
Trims produced per shift: $trimsPerShift$ units
Trims produced per month: $trimsPerMonth$ units
Trim engineering costs: $$trimEC$ (included into cost per trim)
Tooling costs per car: $$trimTC$ (included into cost per trim)

Cost per engine: $$engineCost$
Engine engineering time: $engineET$ months
Engines produced per shift: $enginesPerShift$ units
Engines produced per month: $enginesPerMonth$ units
Engine engineering costs: $$engineEC$ (included into cost per engine)
Tooling costs per engine: $$engineTC$ (included into cost per engine)
]]

--Items meant for modification end here
----------------------------------

function ItemData(et, etmod, pu, ec, mc, tc)
	local data = {
		EngineeringTime = et,
		EngineeringTimeModifier = etmod,
		ProductionUnits = pu,
		EngineeringCosts = ec,
		MaterialCosts = mc,
		ToolingCosts = tc
	}
	return data
end

function ProcessProject(itemData, factorySettings, projectSettings)

	local trimEtModified = itemData.EngineeringTime * itemData.EngineeringTimeModifier
	local employeeCostsPerShift = factorySettings.Employees * factorySettings.EmployeeHourlyRate * factorySettings.WorkingHoursPerShift
	local factoryProductionUnits = itemData.ProductionUnits / (factorySettings.Employees * factorySettings.AutomationAndToolingCoef * factorySettings.ProductionEfficiency)
	
	local carsMadePerShift = factorySettings.WorkingHoursPerShift / factoryProductionUnits
	local carsMadePerDay = carsMadePerShift * factorySettings.Shifts
	local employeeCostsPerDay = employeeCostsPerShift * factorySettings.Shifts
	
	local carsMadePerMonth = carsMadePerDay * WorkingDaysInAMonth
	local employeeCostsPerMonth = employeeCostsPerDay * WorkingDaysInAMonth
	
	local employeeCostsPerCar = employeeCostsPerShift / carsMadePerShift
	local factoryUpkeepPerCar = factorySettings.FactoryUpkeepPerMonth / carsMadePerMonth
	
	local totalEngineeringCosts = itemData.EngineeringCosts * projectSettings.EngineeringTimeFunding * projectSettings.ProductionOptimization
	
	local totalEngineeringTime = trimEtModified / projectSettings.EngineeringTimeFunding
	
	local monthlyEngineeringCosts = totalEngineeringCosts / projectSettings.BreakevenMonths
	local engineeringCostsPerCar = monthlyEngineeringCosts / carsMadePerMonth
	
	local materialCostPerCar = itemData.MaterialCosts / projectSettings.ProductionOptimization
	
	local toolingCosts = itemData.ToolingCosts * (factorySettings.Shifts / 2) * (projectSettings.BreakevenMonths / 60)
	
	local totalCostPerCar = materialCostPerCar + engineeringCostsPerCar + factoryUpkeepPerCar + employeeCostsPerCar + toolingCosts
	
	local retData = {
		Results = {
			CostPerCar = totalCostPerCar,
			EngineeringTime = totalEngineeringTime
		},
		AuxillaryData = {
			CarsMadePerMonth = carsMadePerMonth,
		    CarsMadePerShift = carsMadePerShift,
		    TotalEngineeringCosts = totalEngineeringCosts,
		    ToolingCostsPerCar = toolingCosts
		}
	}
	
	return retData
end

function DoExport(CarCalculator, CarFile)
	UAPI.Log("DoExport: ")
	local value = {}

	local trimResults = CarCalculator.CarInfo.TrimInfo.Results
	local engineResults = CarCalculator.CarInfo.TrimInfo.EngineInfo.ModelInfo.Results

	local trimData = ItemData(trimResults.EngineeringTime, Modifiers.TrimEngineeringTime, trimResults.ManHours, trimResults.EngineeringCosts, 
							trimResults.MaterialCost, trimResults.ToolingCosts)

	local engineData = ItemData(engineResults.EngineeringTime, Modifiers.EngineEngineeringTime, engineResults.ManHours, engineResults.EngineeringCost, 
							engineResults.MaterialCost, engineResults.ToolingCosts)

	local trimProjectResults = ProcessProject(trimData, CarFactorySettings, CarProjectSettings)
	local engineProjectResults = ProcessProject(engineData, EngineFactorySettings, EngineProjectSettings)
	
	local totalCostPerCar = trimProjectResults.Results.CostPerCar + engineProjectResults.Results.CostPerCar
	
	local price = nil
	local profit = nil
	
	if PriceMargin then
		price = totalCostPerCar * (1 + PriceMargin)
		profit = price - totalCostPerCar
	end
	
	local maxCarsPerShift = math.min(trimProjectResults.AuxillaryData.CarsMadePerShift, engineProjectResults.AuxillaryData.CarsMadePerShift)
	local maxCarsPerMonth = math.min(trimProjectResults.AuxillaryData.CarsMadePerMonth, engineProjectResults.AuxillaryData.CarsMadePerMonth)
	
	local totalEngineeringTime  = math.max(trimProjectResults.Results.EngineeringTime, engineProjectResults.Results.EngineeringTime)
	
	local totalEngineeringCosts = trimProjectResults.AuxillaryData.TotalEngineeringCosts + engineProjectResults.AuxillaryData.TotalEngineeringCosts
	
	
	local outputText = (price and profit) and 
						("Car price: $" .. tostring(price) .. "\nPotential profit per car: $" .. tostring(profit) .. "\n\n" .. OutputTemplate) or OutputTemplate
	
	outputText = outputText:gsub("%$totalCost%$", tostring(totalCostPerCar))
	outputText = outputText:gsub("%$totalET%$", tostring(totalEngineeringTime))
	outputText = outputText:gsub("%$maxCarsPerShift%$", tostring(maxCarsPerShift))
	outputText = outputText:gsub("%$maxCarsPerMonth%$", tostring(maxCarsPerMonth))
	outputText = outputText:gsub("%$totalEC%$", tostring(totalEngineeringCosts))
	
	outputText = outputText:gsub("%$trimCost%$", tostring(trimProjectResults.Results.CostPerCar))
	outputText = outputText:gsub("%$trimET%$", tostring(trimProjectResults.Results.EngineeringTime))
	outputText = outputText:gsub("%$trimsPerShift%$", tostring(trimProjectResults.AuxillaryData.CarsMadePerShift))
	outputText = outputText:gsub("%$trimsPerMonth%$", tostring(trimProjectResults.AuxillaryData.CarsMadePerMonth))
	outputText = outputText:gsub("%$trimEC%$", tostring(trimProjectResults.AuxillaryData.TotalEngineeringCosts))
	outputText = outputText:gsub("%$trimTC%$", tostring(trimProjectResults.AuxillaryData.ToolingCostsPerCar))
	
	outputText = outputText:gsub("%$engineCost%$", tostring(engineProjectResults.Results.CostPerCar))
	outputText = outputText:gsub("%$engineET%$", tostring(engineProjectResults.Results.EngineeringTime))
	outputText = outputText:gsub("%$enginesPerShift%$", tostring(engineProjectResults.AuxillaryData.CarsMadePerShift))
	outputText = outputText:gsub("%$enginesPerMonth%$", tostring(engineProjectResults.AuxillaryData.CarsMadePerMonth))
	outputText = outputText:gsub("%$engineEC%$", tostring(engineProjectResults.AuxillaryData.TotalEngineeringCosts))
	outputText = outputText:gsub("%$engineTC%$", tostring(engineProjectResults.AuxillaryData.ToolingCostsPerCar))

	local files = {}

	files["costResults.txt"] = outputText

	return files, {}
end

if CExporter == nil then
	CExporter = {}
	CExporter.__index = CExporter
end

