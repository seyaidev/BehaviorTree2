# BehaviorTree2

BehaviorTree2 is an implementation of the "behavior tree" paradigm for managing behavior. This allows us to create relatively complex patterns of behavior without much getting "lost in the sauce", so to speak. In *behavior trees*, actions are represented as **tasks**, or "leaves". These tasks are then collected in a container called a **tree**, which we "run" through in order to determine what task should be done at a given point in time.

## Nodes
Nodes contain information about how to handle *something*. This can either be a task, or a manipulation of tasks. In BT2, there are 3 types of nodes:
* Tasks
* "Collections"
* Decorators

Creating nodes creates new objects, so be aware of that when reusing them for different agents.

### Tasks
Tasks are the foundation of BT2. They define how to act. Let's take a look at how they're written.

```
local NewNode = BehaviorTree2.Task:new({
    
    -- 'start' and 'finish' functions are optional. only "run" is required!

    start = function(task, object)
        object.i = 0
        print("I've prepped the task!")
    end,

    run = function(task, object)
        object.i = object.i+1
        if object.i == 5 then
            task:success()
            return
        elseif object.i > 5 then
            task:fail()
            return
        end

        print("The task is still running...")
        task:running()
    end,
    
    finish = function(task, object)
        object.i = nil
        print("I'm done with the task!)
    end
});
```
Tasks are created by calling `BehaviorTree2.Task:new()`, with a table defining different **task functions**. When we run a behavior tree, it will "process" a node in the order `start -> run -> finish`. These functions will *always be called in this order*.

The `start` and `finish` functions are usually used to prep and cleanup the work that a task does, like initializing and destroying object properties. However, it is not necessary to define them. A task will function perfectly fine with just the `run` function alone.

#### Task States
As we've noticed in the task functions, there are three methods that are called on the `task` parameter: `task:success()`, `task:fail()`, and `task:running`. These three methods change the **task state**, which determines which node will be processed on the next step. Note that you can **only** call one of these methods every step. Calling `task:success()` then `task:running()` may lead to some unwanted behavior. This is why we `return` after calling `task:success()` in our example.

* `task:success()` : the task finishes successfully and will **move on to the next node**.
* `task:fail()` : the task failed and will **restart the tree**.
* `task:running()` : the task is still processing, so the next step will **run this node again**.

Regardless of whether a node fails or not, keep in mind that it will *always call its task functions* in the order we described. (`start -> run -> finish`)


#### `run`
The `run` function is the "base of operations" for a task. Here, we handle anything we would want to do. When we "run" a behavior tree, we would do so in steps. If we wanted real-time behavior, for example, we could run our trees within `RunService.Heartbeat`. Keep in mind the rate at which you will be processing trees when defining this function. Think about where to change the *task state* of a node when writing your function as well. Consider when it should `fail` so that you don't create unintended behavior. (i.e. attacking when you should be walking instead) Remember that you can **only call one state** per step.

### Selectors
These nodes take multiple `Tasks` and give them order. In BT2, we have `Sequence`, `Priority`, `Random` types for `Selectors`.

#### Sequence
The `Sequence` process the nodes it is given in sequence of the order they are defined. If any of its subnodes fail, then it will not continue to process the `subnodes` that follow it and return a `fail` state itself.

```
Sequence = BehaviorTree2.Sequence:new({
    nodes = {
        node1,
        node2, -- if this failed, the next step would process node1
        node3
    }
})
```
#### Priority
The `Priority` node will process every node until one of them succeeds, after which it will return `success` itself. If none of its subnodes succeed, then this `Selector` would return a `fail` state.

```
Priority = BehaviorTree2.Priority:new({
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
Random = BehaviorTree2.Random:new({
    nodes = {
        node1,
        node2,
        node3
    }
})
```
Nodes can also have an optional `weight` attribute that will affect `Random`. Default is `1`, and is capped at `200`. Two nodes with the same `weight` *should* have equal chances at being selected.

```
node1 = BehaviorTree2.Task:new({
    weight = 10,
    run = function(task, object)
        print("Weight: 10")
        task:success()
    end
})

node2 = BehaviorTree2.Task:new({
    weight = 10,
    run = function(task, object)
        print("Also weight: 10")
        task:success()
    end
})

node3 = BehaviorTree2.Task:new({
    weight = 200,
    run = function(task, object)
        print('You probably won't see "Weight: 10" printed'.)
        task:success()
    end
})
```

### Decorators
Decorators are nodes that wrap other nodes and alter their task state. Right now, there are `AlwaysSucceedDecorator`, `AlwaysFailDecorator`, and `InvertDecorator`. They're pretty self-explanatory, and are helpful for when you start making more complex trees via nested `Collections`.

These can be written as such.
```
Invert = BehaviorTree2.InvertDecorator:new({
    node = nodeHere 
})
```
## The Tree
Once you have your nodes set up and ready to go, we can start planting some trees. A `Tree` starts with any `Selector`, which should have `Task` nodes in them or even other `Selector` nodes with other nodes in them. They can be instantiated by calling `BehaviorTree2:new()` with a `table` containing tree information as its only argument.

```
Tree = BehaviorTree2:new({
    tree = BehaviorTree2.Sequence:new({
        nodes = {
            node1,
            node2,

            BehaviorTree2.Random:new({
                nodes = {
                    node3,
                    node4
                }
            })
        }
    })
})

while true do
    Tree:run()
    wait(1)
end
```
As you can see, we can nest `Selector` nodes within each other. This is where the magic of behavior trees come in! 

### `Tree:setObject()`
If you've noticed back in the `Task` section, there was a second parameter in the task functions called `object`. This is a reference to whatever outside thing the `Tree` might be acting on. We can pass this into the tree by calling `Tree:setObject(thingToSetObjectTo)` before we begin to run the tree. (*To be honest, I've never tried dynamically changing the object of a tree, although I don't see how that could be beneficial*)

```
Tree = BehaviorTree2:new({
    tree = BehaviorTree2.Sequence:new({
        -- nodes from earlier
    })
})

Tree:setObject(Player)

while true do
    Tree:run()
    wait(1)
end
```

That's pretty much all there is to BehaviorTree2. Go nuts with it or something. If you have any issues or questions, feel free to ask about them on the [DevForum post](https://devforum.roblox.com/t/behaviortree2-ai-handling-module/451047). 

Credit to tyridge77 for his work on the optimzations made in his rewrite of the original module, as well as his [new plugin to visually create behavior trees](https://devforum.roblox.com/t/free-btrees-visual-editor-v1-0/461015)!