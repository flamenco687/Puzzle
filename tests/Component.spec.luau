return function ()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local t = require(ReplicatedStorage.t)

    local Component = require(ReplicatedStorage.Puzzle.Component)

    local ComponentInfo = t.interface({
        name = t.string,
        data = t.any
    })

    local name = "Diego"
    local input = 1

    describe(".new", function()
        it("should return a new component", function()
            local component = Component.new(name)
            expect(getmetatable(component)).to.equal(Component)
        end)

        it("that should have a name", function()
            local component = Component.new(name)
            expect(component._name).to.equal(name)
            expect(component._name).to.be.a("string")
        end)
    end)

    describe("__call", function()
        it("should return a ComponentInfo", function()
            local component = Component.new(name)
            expect(assert(ComponentInfo(component(input)))).to.be.ok()

            describe("componentInfo", function()
                it("should contain data matching the input", function()
                    local data = component(input).data
                    expect(data).to.equal(input)
                end)

                it("should contain component's name", function()
                    local componentInfo = component(input)
                    expect(componentInfo.name).to.equal(name)
                end)
            end)
        end)
    end)

    describe("__tostring", function()
        it("should return component's name", function()
            local component = Component.new(name)
            expect(tostring(component)).to.equal(name)
        end)
    end)
end