--!strict
return function ()
    -->> Services

    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    -->> Modules

    local Puzzle = ReplicatedStorage.Puzzle

    local Types = require(Puzzle.Types)
    local World = require(Puzzle.World)
    local Assembler = require(Puzzle.Assembler)

    -->> Variables

    local Color: Types.Assembler<Color3> = Assembler "Color"
    local Size: Types.Assembler<Vector3> = Assembler "Size"

    -->> Descriptions

    describe("New", function()
        describe("Should return a new world", function()
            local world = World()
            expect(getmetatable(world :: any)._isWorld).to.equal(true)

            it("_storage", function()
                expect(world._storage).to.be.a("table")
            end)

            describe("_nextId", function()
                expect(world._nextId).to.be.a("number")

                it("Should equal 1", function()
                    expect(world._nextId).to.equal(1)
                end)
            end)

            describe("_size", function()
                expect(world._size).to.be.a("number")

                it("Should equal 0", function()
                    expect(world._size).to.equal(0)
                end)
            end)
        end)
    end)

    describe("Spawn", function()
        local world = World()

        it("Argument #1: Component Tuple", function()
            expect(
                world:Spawn(
                    Size( Vector3.new() ),
                    Color( Color3.new() )
                )
            ).to.be.ok()
        end)
    end)
end