## tl;dr ##

This repo has grown out of frustrations encountered with web asset build systems and is an exploration into how using existing tools might solve the problem (and perhaps not be as frustrating).  Most tools suffer from trying too hard to be helpful/simple, and end up getting in the way.

The meat is in [build.sh](build.sh) which, when run like this:

```
./build.sh all
```

should:

1. Install/update npm packages
2. Install/update bower components
3. SCSS -> minified CSS
4. JS* -> concatenated, minified JS

```
./build.sh
```

will do just the last 2.

# The Story #

After realizing I could benefit from [SCSS](http://sass-lang.com/) I simultaneously realized that I would need a build system for reliably compiling the SCSS into CSS.  So I turned to [Grunt](http://gruntjs.com/):


## Grunt ##

Grunt has a great logo.  That means it must be a good product.

I installed `grunt`.  Then realized that I actually needed `grunt-cli`.  Then I copied and pasted to make `package.json` and modified some of the dependencies for my needs.  Then I made a basic `Gruntfile.js` (mostly copying and pasting from the web) until I had something that generated minified CSS from my SCSS source.

Sweet!  I mostly felt like I was blindly setting configuration options, but at least it works.

On to the JavaScript.  I have an HTML file that looks like this:

```html
<!doctype html>
<html>
<head>
  <link href="css/base.css" rel="stylesheet">
</head>
<body>
  <script src="bower_components/jquery/dist/jquery.js"></script>
  <script src="bower_components/angular/angular.js"></script>
  <script src="bower_components/angular-animate/angular-animate.js"></script>
  <script src="bower_components/angular-ui-router/release/angular-ui-router.js"></script>
  <script src="js/myapp.js"></script>
</body>
</html>
```

I needed the HTML to remain the same during development, but look something like this in production:

```html
<!doctype html>
<html>
<head>
  <link href="css/base.css" rel="stylesheet">
</head>
<body>
  <script src="js/everything.js"></script>
</body>
</html>
```

Previously, I've done that with [webassets](https://pypi.python.org/pypi/webassets), but that has its own problems (building mostly happens at runtime and the configuration is split confusingly between the template tags and the python code) and it seems like something Grunt should be able to handle.

Enter, [`usemin`](https://github.com/yeoman/grunt-usemin).

By annotating the script list, in the html with comments like this:

```html
<!-- build:js js/app.js -->
<script src="..."></script>
...
<!-- endbuild -->
```

I could use `usemin` to:

1. parse the HTML
2. ngmin the JS files
3. concatenate the JS files
4. uglify the JS files
5. generate a new HTML file with a single script tag.

And all I needed was a magic incantation to put in the `Gruntfile.js`.  I got close, but after several hours, I got tired of trying to guess the parameters to get all the destination files into the right places.  At the time I gave up, the HTML and JS files were successfully being built, but ended up in `dist/` and not in `production/` where I wanted them.


## Thinking ##

Here I was, fiddling the knobs on this irritating `Gruntfile.js` when I thought, "Wait a second.  All I want to do is transform some files into other files.  Why am I building up a JavaScript object to do this?"

At this point, I complained to a friend who mentioned that he'd heard a little about [gulp.js](http://gulpjs.com/).  I checked it out and I liked what I saw:


## gulp.js ##

(Like Grunt, gulp.js also has a great logo--more high quality software ahead.)

As it says on the site:

> By preferring code over configuration, gulp keeps simple things simple and makes complex tasks manageable.

And here's what a sample task looks like:

```javascript
gulp.task('scripts', function() {
  // Minify and copy all JavaScript (except vendor scripts)
  return gulp.src(paths.scripts)
    .pipe(coffee())
    .pipe(uglify())
    .pipe(concat('all.min.js'))
    .pipe(gulp.dest('build/js'));
});
```

"YESSS!!! This is exactly what I want.  Run coffee, then uglify, then concat, then put it into build/js.  I can see exactly<sup>*</sup> what will happen."

<sup>*</sup> read: "not exactly"

So then I went to figure out how to gulp with `usemin`.  It looks like [this](https://github.com/zont/gulp-usemin#usage):

```javascript
gulp.task('usemin', function() {
  gulp.src('./*.html')
    .pipe(usemin({
      css: [minifyCss(), 'concat'],
      html: [minifyHtml({empty: true})],
      js: [uglify(), rev()]
    }))
    .pipe(gulp.dest('build/'));
});
```

Then, since I'm using [AngularJS](http://angularjs.org/), I needed to stick `ngmin` in there somehow.  I tried a few things.

But, then I realized that I was back to fiddling knobs on a box I didn't understand.

I probably wasn't giving gulp.js a fair chance trying to use it after building up several hours worth of frustration with Grunt on a Friday afternoon.  And then we had a terribly long and irritating meeting at work.

I came back and stared at the gulp.js code and read some more stuff.  Eventually, I fixated on that `pipe` function.

"Pipe.  Pipe.  Pipe?"

I know about pipes!  They look like this: `|` and come from the [year 1989](http://en.wikipedia.org/wiki/Bash_(Unix_shell)).


## bash ##

I have a bunch of files that I want to turn into other files.  `bash` is great for things like that!

And so, I made [build.sh](build.sh).  It's not perfect, but it's understandable and debuggable.  Concatenating files becomes:

```bash
cat $inputs > $output
```

Concatenating and uglifying looks like this:

```bash
cat $inputs | uglifyjs > $output
```

If `uglifyjs` doesn't seem to be behaving right, I can run it from the command line to figure out what I need to do differently.


## What it lacks ##

It's not a perfect solution and it has some warts compared to Grunt and gulp:

1. It looks like [potato programming](http://divmod.readthedocs.org/en/latest/philosophy/potato.html) right now.  (This is fixable)

2. It's longer.

3. At a glance, it's not easier to comprehend (probably because of all the variables) and potato programming.

4. It doesn't have watching built in (not sure it needs to be built in, though).

5. It only workon on *nix systems.


## A note about Makefiles ##

I tried using a Makefile several times.  One problem I encountered (I'd be interested in a solution) was that not all the input files are known until you parse the HTML file to find them.  How do you write a `target: dependencies` when the dependencies are buried in an HTML file?

