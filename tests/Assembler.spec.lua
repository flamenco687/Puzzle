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
        describe("should return: a new assembler", function()
            local assembler = Assembler(name) :: any

            expect(getmetatable(assembler)._isAssembler).to.equal(true)

            describe("_name", function()
                it("should equal: assembler's name", function()
                    expect((assembler :: Assembler._Assembler<any>)._name).to.equal(name)
                end)
            end)
        end)
    end)

    describe("__call", function()
        local assembler = Assembler(name)

        describe("should return: a component", function()
            expect( if not Types.Component(assembler(input)) then error(false) else true ).to.be.ok()

            describe("data", function()
                local data = assembler(input).data

                it("should match: the input value", function()
                    expect(data).to.equal(input)
                end)
            end)

            describe("name", function()
                local component = assembler(input)

                it("should equal: assembler's name", function()
                    expect(component.name).to.equal(name)
                end)
            end)
        end)
    end)

    describe("__tostring", function()
        local assembler = Assembler(name)

        it("should return: assembler's name", function()
            expect(tostring(assembler)).to.equal(name)
        end)
    end)
end