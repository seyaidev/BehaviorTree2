# BehaviorTree3

This module is a fork of BehaviorTrees2 by oniich_n. The following are the improvements/changes:
* Previously, Decorators would only work when parented to Task node. Now, they can be placed arbirarily, and even chained together, and will work as expected. Internally, decorators work slightly differently, but I preserved the clever and efficient tree traversal algorithm that oniich_n implemented in BehaviorTrees2. Should still be just as fast.
* Calling tree:run() will return the outcome of the tree (success [1], fail [2], running [3])
* Added repeater node
    * can repeat infinitely with a "count" parameter of nil or <= 0
    * returns success when done repeating
    * returns fail if a "breakonfail" parameter is true and it receives a failed result from its child
* Added tree node which will call another tree and return the result of the other tree
* If a success/fail node is left hanging without a child, it will directly return success/fail
* Improved ProcessNode organization and readability by adding the interateNodes() iterator and the addNode() function
* Changed node runner from using string node states to using number enums, to avoid string comparisons. Should be slightly faster.
* Changed tasks to report their status by returning a status number enum, instead of calling a success/fail/running function on self
* Added some more assertions in ProcessNode
* Added comments and documentation so it's a little easier to add new nodes
* Changed "Task"/"Selector" language to more generic "Leaf"/"Composite"

BehaviorTree3 is an implementation of the "behavior tree" paradigm for managing behavior. This allows us to create relatively complex patterns of behavior without much getting "lost in the sauce", so to speak. In *behavior trees*, actions are represented as **tasks**, or "leaves". These tasks are then collected in a container called a **tree**, which we "run" through in order to determine what task should be done at a given point in time.

## Nodes
Nodes contain information about how to handle *something*. This can either be a task, or a manipulation of tasks. In BT2, there are 3 types of nodes:
* Leafs
* Composites
* Decorators

Creating nodes creates new objects, so be aware of that when reusing them for different agents.

### Leafs
Leafs are the foundation of BT3. They define how to act.

#### Tasks
The most commonly used leaf is a `Task`. Let's take a look at how they're written.

```
local SUCCESS,FAIL,RUNNING = 1,2,3

local NewNode = BehaviorTree3.Task({
    
    -- 'start' and 'finish' functions are optional. only "run" is required!

    start = function(object)
        object.i = 0
        print("I've prepped the task!")
    end,

    run = function(object)
        object.i = object.i+1
        if object.i == 5 then
            return SUCCESS
        elseif object.i > 5 then
            return FAIL
        end

        print("The task is still running...")
        return RUNNING
    end,
    
    finish = function(object)
        object.i = nil
        print("I'm done with the task!)
    end
})
```
Tasks are created by calling `BehaviorTree2.Task()`, with a table defining different **task functions**. When we run a behavior tree, it will "process" a node in the order `start -> run -> finish`. These functions will *always be called in this order*.

The `start` and `finish` functions are usually used to prep and cleanup the work that a task does, like initializing and destroying object properties. However, it is not necessary to define them. A task will function perfectly fine with just the `run` function alone.

The `run` function is the "base of operations" for a task. Here, we handle anything we would want to do. When we "run" a behavior tree, we would do so in steps. If we wanted real-time behavior, for example, we could run our trees within `RunService.Heartbeat`. Keep in mind the rate at which you will be processing trees when defining this function. Think about where to change the *task state* of a node when writing your function as well. Consider when it should `fail` so that you don't create unintended behavior. (i.e. attacking when you should be walking instead) Remember that you can **only call one state** per step.

#### Trees
The `Tree` is a special `Leaf` type that will execute another tree and pass the result of that tree to its parent.

```
local AnotherTree = BehaviorTree3:new(...)
local NewNode = BehaviorTree3.Task({tree = AnotherTree})
````
### Composites
These nodes take multiple `Leafs` and give them order. In BT3, we have `Sequence`, `Selector`, `Random` types for `Compites`.

#### Sequence
The `Sequence` process the nodes it is given in sequence of the order they are defined. If any of its subnodes fail, then it will not continue to process the `subnodes` that follow it and return a `fail` state itself.

```
Sequence = BehaviorTree3.Sequence({
    nodes = {
        node1,
        node2, -- if this failed, the next step would process node1
        node3
    }
})
```
#### Selector
The `Selector` node will process every node until one of them succeeds, after which it will return `success` itself. If none of its subnodes succeed, then this `Composite` would return a `fail` state.

```
Priority = BehaviorTree3.Selector({
    nodes = {
        node1,
        node2,
        node3 -- this is the only node that suceeded, so Priority would return success
    }
})
```
#### Random
This `Selector` will randomly select a subnode to process, and will return whatever state that node returns.
```
Random = BehaviorTree3.Random({
    nodes = {
        node1,
        node2,
        node3
    }
})
```
Nodes can also have an optional `weight` attribute that will affect `Random`. Default is `1`.

```
node1 = BehaviorTree3.Task({
    weight = 10,
    run = function(task, object)
        print("Weight: 10")
        task:success()
    end
})

node2 = BehaviorTree3.Task({
    weight = 10,
    run = function(task, object)
        print("Also weight: 10")
        task:success()
    end
})

node3 = BehaviorTree3.Task({
    weight = 200,
    run = function(task, object)
        print('You probably won't see "Weight: 10" printed'.)
        task:success()
    end
})
```

### Decorators
Decorators are nodes that wrap other nodes and alter their task state. Right now, there are `Succeed`, `Fail`, `Invert`, and `Repeat` decorators. `Succeed`, `Fail`, and `Invert` are pretty self-explanatory, and are helpful for when you start making more complex trees via nested `Collections`. 

These can be written as such.
```
Invert = BehaviorTree3.Invert({
    node = nodeHere 
})
````
`Repeat` decorators will repeat their children node tasks until `count`, or indefinitely if `count` is nil or < 0, after which they will return a `success` state. If `breakonfail` is true and its child node fails, it will stop repeating and return a `fail` state.
````
Repeat = BehaviorTree3.Repeat({
    node = nodeHere,
    count = 3,
    breakonfail = true
})
````
## The Tree
Once you have your nodes set up and ready to go, we can start planting some trees. A `Tree` starts with any `Selector`, which should have `Task` nodes in them or even other `Selector` nodes with other nodes in them. They can be instantiated by calling `BehaviorTree2:new()` with a `table` containing tree information as its only argument.

```
Tree = BehaviorTree3:new({
    tree = BehaviorTree3.Sequence({
        nodes = {
            node1,
            node2,

            BehaviorTree3.Random({
                nodes = {
                    node3,
                    node4
                }
            })
        }
    })
})

while true do
    local treeStatus = Tree:run()
    wait(1)
end
```
As you can see, we can nest `Composite` nodes within each other. This is where the magic of behavior trees come in! 

### `Tree:setObject()`
If you've noticed back in the `Task` section, there was a second parameter in the task functions called `object`. This is a reference to whatever outside thing the `Tree` might be acting on. We can pass this into the tree by calling `Tree:setObject(thingToSetObjectTo)` before we begin to run the tree. (*To be honest, I've never tried dynamically changing the object of a tree, although I don't see how that could be beneficial*)

```
Tree = BehaviorTree3:new({
    tree = BehaviorTree2.Sequence({
        -- nodes from earlier
    })
})

Tree:setObject(Player)

while true do
    local treeStatus = Tree:run()
    wait(1)
end
```

That's pretty much all there is to BehaviorTree3. Go nuts with it or something. If you have any issues or questions, feel free to ask about them on the devforum post [TBD]. 
