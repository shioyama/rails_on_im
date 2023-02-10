# Rails on Im

This is a Rails 7.0 app demonstrating how [Im](https://github.com/shioyama/im)
can be used to "hoist" classes and modules of a Rails application under a
single root namespace, while writing the actual code at toplevel. Among other
benefits, this means you can write your application code exactly as you always
do, but avoid any conflicts with gems or other imported code.

## Usage

This _should_ be just like any Rails app from the outside. Boot it with
`bin/rails server`, go to the `/posts` index page and click around. The point
is not to have a beatiful application, simply to reproduce what `bin/rails
generate scaffold` would normally give you, but with a very different
implementation.

To see what is going on, have a look first at
[`app/models/post.rb`](https://github.com/shioyama/rails_on_im/blob/main/app/models/post.rb)
and
[`app/models/comment.rb`](https://github.com/shioyama/rails_on_im/blob/main/app/models/comment.rb).
You will see that these files define top-level `Post`
and `Comment` classes, as well as associations between them. In a normal Rails
app, this would mean that you could access `Post` and `Comment` from anywhere,
but this application is implemented differently.

To see this, start `irb` and try accessing the `Post` model:

```
irb(main):001:0> Post
(irb):1:in `<main>': uninitialized constant Post (NameError)

Post
^^^^
```

So it is not defined at toplevel, yet the application works. That is because
the application is using Im to "hoist" the autoloaded application constants
under `MyApp::Application`, where you can find them:

```
irb(main):002:0> MyApp::Application::Post
=> MyApp::Application::Post (call 'MyApp::Application::Post.connection' to establish a connection)
```

This means, among other things, that you can define constants that would
normally be reserved. The demo app has one such constant: `Kernel`, defined in
`app/models/kernel.rb` at toplevel but loaded at `MyApp::Application::Kernel`:

```ruby
Kernel
#=> Kernel
MyApp::Application::Kernel
#=> MyApp::Application::Kernel (call 'MyApp::Application::Kernel.connection' to establish a connection)
```

Note that because the toplevel of the application is its own constant, you can
easily see all application toplevel constants simply by calling `constants` on `MyApp::Application`, like this:

```ruby
MyApp::Application.constants
#=>
[:Post,
 :RestrictedAccess,
 :Kernel,
 :Tag,
 :Comment,
 :ApplicationCable,
 :ApplicationController,
 :CommentsController,
 :PingController,
 :PostsController,
 :ApplicationHelper,
 :CommentsHelper,
 :PostsHelper,
 :ApplicationJob,
 :ApplicationMailer,
 :ApplicationRecord]
 ```

`MyApp::Application` itself is an instance of `Im::Loader`, Im's loader for the
application (see details below). The usual `Application` class, which points to
`Rails.application`, is instead named `MyApp::RailsApplication`.

## Details

Most of the changes required to support the hoisting of constants under
`MyApp::Application` can be found in
[`config/application.rb`](https://github.com/shioyama/rails_on_im/blob/main/config/application.rb).
Other changes are confined to `Application` classes `ApplicationRecord` and
`ApplicationController`, while subclasses are written exactly as they would be
in a normal Rails app.

### Autoload paths

The main issue in using Im to autoload paths is that, while Rails allows for
multiple autoloaders, it uses only one (`Rails.autoloaders.main`) to load both
parts of Rails itself _and_ the application. This is problematic because we
want to let Rails use the normal
[Zeitwerk](https://github.com/shioyama/rails_on_im/blob/main/config/application.rb)
autoloader for Rails code, and only switch the application autoloader to use Im
instead.

To get around this limitation, the demo app extracts application paths from
`ActiveSupport::Dependencies.autoload_paths`, removes them, and assigns them to
an Im loader with `loader.push_dir`. The code for this is nearly identical to
what Rails uses internally to assign autoload paths to the Zeitwerk loader.

### Reloading the Application

Removing application paths from Rails' default `autoload_paths` has some
secondary effects that need to be handled. The main one is that application
reloading depends on `autoload_paths`, and since we remove the application from
these paths, Rails' default autoloading strategy will not work on Im-managed
paths.

This is handled first by adding a hook to the instance of `Zeitwerk::Loader` in
`Rails.autoloaders.main`. We simply patch the method so that every time Rails
calls `reload` on it, the application Im loader also gets triggered, ensuring
Im-loaded code is also reloaded.

Rails also uses `autoload_paths` to determine which files and directories to
watch, thus by default changes to files in a running application in development
mode will not get reloaded. Luckily, Rails has a configuration option to add
`watchable_files` and `watchable_dirs` manually, which we use to iterate
through all the autoloads handled by the Im loader and add them so they are
also watched.

Finally, Rails adds an `on_load` hook to the Zeitwerk loader to add tracked
classes and their descendants to a registry
(`ActiveSupport::Dependencies._autoloaded_tracked_classes`) when they are
loaded. We simply add the same hook to the Im loader to ensure this works as
expected.

### Reloading Routes

Reloading routes in Rails is done by an instance of
`Rails::Application::RoutesReloader` returned by the `routes_reloader` method
on the application. Routes reloading is independent of Zeitwerk and happens by
calling `Kernel#load` on the routes path, which by default is `config/routes.rb`.

The problem with this is that any application constant referenced at toplevel
in the routes file will not resolve correctly, since `load` loads the file at
toplevel. We handle this by subclassing `Rails::Application::RoutesReloader` in
order to override `load` to pass the application loader (`MyApp::Application`)
as the second argument, ensuring that constants referenced at toplevel in
`config/routes.rb` will resolve to the application namespace.

A demonstration of this can be found in
[`config/routes.rb`](https://github.com/shioyama/rails_on_im/blob/main/config/routes.rb)
where the autoloaded constant `RestrictedAccess` is resolved at toplevel to
`app/models/restricted_access.rb`, although the actual constant is hoisted
under `MyApp::Application` (like all other autoloaded constants.)

### File path conventions

The other issue that we face with this novel configuration is that certain
conventions around file and route naming break down due to the file structure.

We have this:

```
app/models/application_record.rb          #=> MyApp::Application::ApplicationRecord
app/models/post.rb                        #=> MyApp::Application::Post
app/models/comment.rb                     #=> MyApp::Application::Comment

app/controllers/application_controller.rb #=> MyApp::Application::ApplicationController
app/controllers/posts_controller.rb       #=> MyApp::Application::PostsController
app/controllers/comments_controller.rb    #=> MyApp::Application::CommentsController
...
```

While we have our classes namespaced, we still want the application to use
toplevel routes (`/posts`, `/comments`, etc.), map our models to those toplevel
routes, and so on.

Just a few changes are needed to make this unconventional setup work.

First, we define a method `use_relative_model_naming?` on `MyApp::Application`
to tell Rails to consider model names as being under a namespace
`my_app/application` when generating url helpers for models. So this ensures
that url helpers, when passed instances of an `MyApp::Application::Post`, will
correctly deduce that its param key is `post` and not `my_app_application_post`.

To make this work, we also need to wrap our application routes so that they too
map, for example, `/posts` to the correct controller and models. This is easy
to do simply by wrapping all routes in a scope, like this:

```ruby
# config/routes.rb
  scope module: "my_app/application" do
    resources :posts do
```

Rails will also try to load `ApplicationHelper` when it sees
`app/helpers/application_helper.rb`, even though that constant is not defined
at (absolute) toplevel. To avoid this, we disable
config.action_controller.include_all_helpers`. This is not an ideal fix and
should probaly be revisited, but it works for demonstration purposes.

Finally, two small changes are needed in `ApplicationController` and
`ApplicationRecord` to put the final pieces in place. In
`ApplicationController`, we override the default `controller_path` to remove
the autogenerated `"my_app/application"` prefix and ensure it returns `posts`
rather than `my_app/application/posts`. Likewise, in `ApplicationRecord`, we
override `to_partial_path` in the same way.

With these changes, we have a working Rails application in which our code is
written at toplevel, but all constants are defined under a single toplevel
namespace.

## Comments & Feedback

This is very much an experimental work in progress. If you try it out and find
issues either in the application or in Im itself, feel free to post issues or
pull requests.
