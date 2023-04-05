--!strict
return function ()
    -->> Services

    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    -->> Modules

    local Puzzle = ReplicatedStorage.Puzzle

    local Types = require(Puzzle.Types)
    local Assembler = require(Puzzle.Assembler)

    -->> Variables

    local name: string = "Position"
    local input: number = 1

    -->> Descriptions

    describe("new", function()
        it("should return a new assembler", function()
            local assembler = Assembler(name)
            expect(getmetatable(assembler :: any)).to.equal(Assembler(true :: any))
        end)

        it("that should have a name", function()
            local assembler: { _name: string } = Assembler(name) :: any
            expect(assembler._name).to.equal(name)
            expect(assembler._name).to.be.a("string")
        end)
    end)

    describe("__call", function()
        it("should return a component", function()
            local assembler = Assembler(name)
            expect( if not Types.Component( assembler(input) ) then error() else true ).to.be.ok()

            describe("Component", function()
                it("should contain data matching the input", function()
                    local data = assembler(input).data
                    expect(data).to.equal(input)
                end)

                it("should contain the component's name", function()
                    local component = assembler(input)
                    expect(component.name).to.equal(name)
                end)
            end)
        end)
    end)

    describe("__tostring", function()
        it("should return the component's name", function()
            local assembler = Assembler(name)
            expect(tostring(assembler)).to.equal(name)
        end)
    end)
end