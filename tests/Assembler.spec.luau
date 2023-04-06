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

    describe("New", function()
        describe("Should return a new assembler", function()
            local assembler = Assembler(name) :: any
            expect(getmetatable(assembler :: any)._isAssembler).to.equal(true)

            it("Should have a name", function()
                expect((assembler :: {_name: string})._name).to.equal(name)
            end)
        end)
    end)

    describe("__call", function()
        describe("Should return a component", function()
            local assembler = Assembler(name)
            expect( if not Types.Component( assembler(input) ) then error() else true ).to.be.ok()

            it("Should have data matching the input", function()
                local data = assembler(input).data
                expect(data).to.equal(input)
            end)

            it("Should have name matching assembler's name", function()
                local component = assembler(input)
                expect(component.name).to.equal(name)
            end)
        end)
    end)

    describe("__tostring", function()
        it("Should return assembler's name", function()
            local assembler = Assembler(name)
            expect(tostring(assembler)).to.equal(name)
        end)
    end)
end