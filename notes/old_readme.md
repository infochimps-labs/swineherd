Swineherd is for running scripts and workflows on filesystems.

h3. Outline

A @workflow@ is built with @script@ objects and ran on a @filesystem@.

h4. Script:

A script has the following

* @source@ - The source file used. These can be "Apache Pig":http://pig.apache.org/ scripts, "Wukong":http://github.com/infochimps/wukong scripts, even "R":http://www.r-project.org/ scripts. You can add your own scripts by subclassing the @script@ class. 
* @input@ - An array of input paths.
* @output@ - An array of output paths.
* @options@ - A ruby hash of options used as command line args. Eg. {:foo => 'bar'}. How these options are mapped to command line arguments is up to the particular script class.
* @attributes@ - A ruby hash of parameters used for variable substitution. Every script is assumed to be (but not required to be) an eruby template.

h4. Workflow:

A workflow is built using rake @task@ objects that doing nothing more than run scripts. A workflow

* can be described with a directed dependency graph
* has an @id@ which is used to run its tasks idempotently. At the moment it is the responsibility of the running process (or human being) to choose a suitable id.
* manages intermediate outputs by using the @next_output@ and @latest_output@ methods. See the examples dir for usage.
* A workflow has a working directory in which all intermediate outputs go
** These are named according to the rake task that created them

h4. FileSystem

Workflows are intended to run on filesystems. At the moment, implemented filesystems are

* @file@ - Local file system. Only thoroughly tested on unbuntu linux.
* @hdfs@ - Hadoop distributed file system. Uses jruby and the Apache Hadoop 0.20 api.
* @s3@ - Uses the right_aws gem for interacting with Amazon Simple Storage System (s3).

Using the filesystem:

Paths should be absolute.

<pre><code>
# get a new instance of local filesystem and write to it
localfs = FileSystem.get(:file)
localfs.open("mylocalfile", 'w') do |f|
  f.write("Writing a string to a local file")
end

# get a new instance of hadoop filesystem and write to it
hadoopfs = FileSystem.get(:hdfs)
hadoopfs.open("myhadoopfile", 'w') do |f|
  f.write("Writing a string to an hdfs file")
end

# get a new instance of s3 filesystem and write to it
access_key_id     = '1234abcd'
secret_access_key = 'foobar1234'
s3fs = FileSystem.get(:s3, accees_key_id, secret_access_key)
s3fs.mkpath 'mys3bucket' # bucket must exist
s3fs.open("mys3bucket/mys3file", 'w') do |f|
  f.write("Writing a string to an s3 file")
end
</code></pre>

h3. Working Example

For the most up to date working example see the examples directory. Here's a simple example for running pagerank:

<pre><code>
#!/usr/bin/env ruby

$LOAD_PATH << '../../lib'
require 'swineherd'        ; include Swineherd
require 'swineherd/script' ; include Swineherd::Script
require 'swineherd/filesystem'

Settings.define :flow_id,     :required => true,                     :description => "Flow id required to make run of workflow unique"
Settings.define :iterations,  :type => Integer,  :default => 10,     :description => "Number of pagerank iterations to run"
Settings.define :hadoop_home, :default => '/usr/local/share/hadoop', :description => "Path to hadoop config"
Settings.resolve!

flow = Workflow.new(Settings.flow_id) do

  # The filesystems we're going to be working with
  hdfs    = Swineherd::FileSystem.get(:hdfs)
  localfs = Swineherd::FileSystem.get(:file)

  # The scripts we're going to use
  initializer = PigScript.new('scripts/pagerank_initialize.pig')
  iterator    = PigScript.new('scripts/pagerank.pig')
  finisher    = WukongScript.new('scripts/cut_off_list.rb')
  plotter     = RScript.new('scripts/histogram.R')

  #
  # Runs simple pig script to initialize pagerank. We must specify the input
  # here as this is the first step in the workflow. The output attribute is to
  # ensure idempotency and the options attribute is the hash that will be
  # converted into command-line args for the pig interpreter.
  #
  task :pagerank_initialize do
    initializer.options = {:adjlist => "/tmp/pagerank_example/seinfeld_network.tsv", :initgrph => next_output(:pagerank_initialize)}
    initializer.run(:hadoop) unless hdfs.exists? latest_output(:pagerank_initialize)
  end

  #
  # Runs multiple iterations of pagerank with another pig script and manages all
  # the intermediate outputs.
  #
  task :pagerank_iterate => [:pagerank_initialize] do
    iterator.options[:damp]           = '0.85f'
    iterator.options[:curr_iter_file] = latest_output(:pagerank_initialize)
    Settings.iterations.times do
      iterator.options[:next_iter_file] = next_output(:pagerank_iterate)
      iterator.run(:hadoop) unless hdfs.exists? latest_output(:pagerank_iterate)
      iterator.refresh!
      iterator.options[:curr_iter_file] = latest_output(:pagerank_iterate)
    end
  end

  #
  # Here we use a wukong script to cut off the last field (a big pig bag of
  # links). Notice how every wukong script MUST have an input but pig scripts do
  # not.
  #
  task :cut_off_adjacency_list => [:pagerank_iterate] do
    finisher.input  << latest_output(:pagerank_iterate)
    finisher.output << next_output(:cut_off_adjacency_list)
    finisher.run :hadoop unless hdfs.exists? latest_output(:cut_off_adjacency_list)
  end

  #
  # We want to pull down one result file, merge the part-000.. files into one file
  #
  task :merge_results => [:cut_off_adjacency_list] do
    merged_results = next_output(:merge_results)
    hdfs.merge(latest_output(:cut_off_adjacency_list), merged_results) unless hdfs.exists? merged_results
  end

  #
  # Cat results into a local directory with the same structure
  # eg. #{work_dir}/#{flow_id}/pull_down_results-0.
  #
  # FIXME: Bridging filesystems is cludgey.
  #
  task :pull_down_results => [:merge_results] do
    local_results = next_output(:pull_down_results)
    hdfs.copy_to_local(latest_output(:merge_results), local_results) unless localfs.exists? local_results
  end

  #
  # Plot 2nd column of the result as a histogram (requires R and
  # ggplot2). Note that the output here is a png file but doesn't have that
  # extension. Ensmarten me as to the right way to handle that?
  #
  task :plot_results =>  [:pull_down_results] do
    plotter.attributes = {
      :pagerank_data => latest_output(:pull_down_results),
      :plot_file     => next_output(:plot_results), # <-- this will be a png...
      :raw_rank      => "aes(x=d$V2)"
    }
    plotter.run(:local) unless localfs.exists? latest_output(:plot_results)
  end

end

flow.workdir = "/tmp/pagerank_example"
flow.describe
flow.run(:plot_results)
</code></pre>

h3. Utils

There's a fun little program to emphasize the ease of using the filesystem abstraction called 'hdp-tree':

<pre><code>
$: bin/hdp-tree /tmp/my_hdfs_directory
--- 
/tmp/my_hdfs_directory: 
  - my_hdfs_directory: 
      - sub_dir_a: leaf_file_1
      - sub_dir_a: leaf_file_2
      - sub_dir_a: leaf_file_3
  - my_hdfs_directory: 
      - sub_dir_b: leaf_file_1
      - sub_dir_b: leaf_file_2
      - sub_dir_b: leaf_file_3
  - my_hdfs_directory: 
      - sub_dir_c: leaf_file_1
      - sub_dir_c: leaf_file_2
      - sub_dir_c: leaf_file_3
      - sub_dir_c: 
          - sub_sub_dir_a: yet_another_leaf_file
      - sub_dir_c: sub_sub_dir_b
      - sub_dir_c: sub_sub_dir_c
</code></pre>

I know, it's not as pretty as unix tree, but this IS github...

h3. TODO

* next task in a workflow should NOT run if the previous step failed
** this is made difficult by the fact that, sometimes?, when a pig script fails it still returns a 0 exit status
** same for wukong scripts
* add a @job@ object that implements a @not_if@ function. this way a @workflow@ will be constructed of @job@ objects
** a @job@ will do nothing more than execute the ruby code in it's (run?) block, unless @not_if@ is true
** this way we can put @script@ objects inside a @job@ and only run under certain conditions that the user specifies when
   they create the @job@
* implement ftp filesystem interfaces
