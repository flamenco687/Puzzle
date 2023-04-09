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
    local Tag: Types.Assembler<string> = Assembler "Tag"

    -->> Descriptions

    describe("New", function()
        describe("should return a new world", function()
            local world = World() :: World._World

            expect(getmetatable(world :: any)._isWorld).to.equal(true)

            it("_storage", function()
                expect(world._storage).to.be.a("table")
            end)

            describe("_nextId", function()
                expect(world._nextId).to.be.a("number")

                it("should equal: 1", function()
                    expect(world._nextId).to.equal(1)
                end)
            end)

            describe("_size", function()
                expect(world._size).to.be.a("number")

                it("should equal: 0", function()
                    expect(world._size).to.equal(0)
                end)
            end)
        end)
    end)

    describe("Spawn", function()
        local world = World() :: World._World

        local size = world._size
        local nextId = world._nextId

        it("should accept as #1: a component tuple", function()
            expect(
                world:Spawn(
                    Color(Color3.new()),
                    Size(Vector3.new())
                )
            ).to.be.ok()
        end)

        it("should increase by 1: _nextId", function()
            expect(world._nextId).to.equal(nextId + 1)
        end)

        it("should increase by 1: _size", function()
            expect(world._size).to.equal(size + 1)
        end)
    end)

    describe("Remove", function()
        local world = World() :: World._World

        world:Spawn(Color(Color3.new()))

        local size = world._size
        local nextId = world._nextId

        it("should accept as #1: an id", function()
            expect( world:Remove(1) ).to.be.ok()
        end)

        it("should decrease by 1: _nextId", function()
            expect(world._nextId).to.equal(nextId - 1)
        end)

        it("should decrease by 1: _size", function()
            expect(world._size).to.equal(size - 1)
        end)

        it("should clear storage if it's the last entity", function()
            expect(world._storage.Color).to.never.be.ok()
        end)
    end)

    describe("Get", function()
        local world = World() :: World._World

        world:Spawn(
            Color(Color3.new()),
            Size(Vector3.new())
        )

        local components = world:Get(1)
        local size, color = world:Get(1, Size, Color)

        it("should accept as #1: an id", function()
            expect(world:Get(1)).to.be.ok()
        end)

        it("should return: a component dictionary", function()
            expect(components.Color).to.equal(Color3.new())
            expect(components.Size).to.equal(Vector3.new())

            local count = 0

            for _ in components do
                count += 1
            end

            expect(count).to.equal(2)
        end)

        describe("might accept as #2: an assembler tuple", function()
            expect(world:Get(1, Size, Color)).to.be.ok()

            it("should return instead: a component tuple", function()
                expect(size).to.equal(Vector3.new())
                expect(color).to.equal(Color3.new())
            end)
        end)
    end)

    describe("Set", function()
        local world = World() :: World._World

        world:Spawn(
            Color(Color3.new(1, 1, 1)),
            Size(Vector3.new(1, 1, 1)),
            Tag("string")
        )

        local components = world:Get(1)

        it("should accept as #1: an id", function()
            expect(
                world:Set(
                    1,
                    Color(Color3.new()),
                    Size(Vector3.new())
                )
            ).to.be.ok()
        end)

        it("should accept as #2: a component tuple", function()
            expect(
                world:Set(
                    1,
                    Color(Color3.new()),
                    Size(Vector3.new())
                )
            ).to.be.ok()
        end)

        it("should only update passed components", function()
            expect(components.Color).to.never.equal(world:Get(1, Color))
            expect(components.Size).to.never.equal(world:Get(1, Size))
            expect(components.Tag).to.equal(world:Get(1, Tag))
        end)
    end)
end