local acceptVersionStrategy = require('./strategies/accept-version')
local acceptHostStrategy = require('./strategies/accept-host')
local assert = require('assert')

local Constrainer = {}

function Constrainer:new (customStrategies)
    local strategies = {
        version = acceptVersionStrategy,
        host = acceptHostStrategy
    }

    local strategiesInUse = {}
    local asyncStrategiesInUse = {}

    if customStrategies then
        for _, strategy in ipairs(customStrategies) do
            strategiesInUse[#strategiesInUse + 1] = strategy
        end
    end

    function isStrategyUsed (strategyName)
        for _, strategy in ipairs(strategiesInUse) do
            if strategyName == strategy.name then
                return true
            end
        end
        return false
    end

    function hasConstraintStrategy (strategyName)
        local customConstraintStrategy = strategies[strategyName]
        if customConstraintStrategy then
            if customConstraintStrategy.isCustom or isStrategyUsed(strategyName) then
                return true
            end
        end
        return false
    end

    function addConstraintStrategy (strategy)
        assert(type(strategy.name) == "string" and strategy.name ~= "", "strategy.name is required.")
        assert(strategy.storage and type(strategy.storage) == "function", "strategy.storage function is required.")
        assert(strategy.deriveConstraint and type(strategy.deriveConstraint) == "function", "strategy.deriveConstraint function is required.")

        if strategies[strategy.name] and strategies[strategy.name].isCustom then
            error("There already exists a custom constraint with the name " .. strategy.name)
        end

        if isStrategyUsed(strategy.name) then
            error("There already exists a route with " .. strategy.name .. " constraint.")
        end

        strategy.isCustom = true
        strategy.isAsync = strategy.deriveConstraint.nargs == 3
        strategies[strategy.name] = strategy

        if strategy.mustMatchWhenDerived then
            strategiesInUse[#strategiesInUse + 1] = strategy
        end
    end

    function deriveConstraints (req, ctx, done)
        local constraints = nil

        if strategiesInUse[1] then
            constraints = strategiesInUse[1].deriveConstraint(req, ctx)
        end

        if done == undefined then
            return constraints
        end

        local asyncConstraintsCount = asyncStrategiesInUse[1]

        if asyncConstraintsCount == 0 then
            done(nil, constraints)
            return
        end

        constraints = constraints or {}
        for _, key in ipairs(asyncStrategiesInUse) do
            local strategy = strategies[key]
            strategy.deriveConstraint(req, ctx, function (err, constraintValue)
                if err then
                    done(err)
                    return
                end

                constraints[key] = constraintValue

                if --asyncConstraintsCount == 0 then
                    done(null, constraints)
                end
            end)
        end
    end

    function newStoreForConstraint (constraint)
        local strategy = strategies[constraint]
        if not strategy then
            error("No strategy registered for constraint key " .. constraint)
        end
        return strategy.storage()
    end

    function validateConstraints (constraints)
        for _, value in ipairs(constraints) do
            local strategy = strategies[_]
            if not strategy then
                error("No strategy registered for constraint key " .. _)
            end
            if strategy.validate and strategy.validate(value) then
                continue
            else
                return false
            end
        end
        return true
    end
end

return Constrainer
