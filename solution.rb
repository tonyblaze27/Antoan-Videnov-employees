require 'csv'
require 'date'
require 'gtk3'


def load_data(file_path)
  data = []
   CSV.foreach(file_path, headers: true) do |row|
        stripped_row = row.to_h.transform_values(&:strip)
        data << [stripped_row['EmpID'].to_i, stripped_row['ProjectID'].to_i, parse_date(stripped_row['DateFrom']), parse_date(stripped_row['DateTo'])]  
   end
  data
end


def parse_date(date_str)
  return Date.today if date_str.nil? || date_str.empty? || date_str == 'NULL'
  
  supported_formats = [
    '%Y-%m-%d',
    '%m/%d/%Y',
    '%m/%d/%y',
    '%d/%m/%Y',
    '%d-%m-%Y',
    '%d/%m/%y'
  ]

  supported_formats.each do |format|
    begin
      return Date.strptime(date_str, format)
    rescue ArgumentError
      next
    end
  end

  raise ArgumentError, "Unsupported date format: #{date_str}"
end


def overlap_days(date_range1, date_range2)
  overlap = [0, [date_range1.last, date_range2.last].min - [date_range1.first, date_range2.first].max].max
  overlap
end


def select_file
  dialog = Gtk::FileChooserDialog.new(
    title: "Please, select CSV file",
    parent: nil,
    action: Gtk::FileChooserAction::OPEN,
    buttons: [
      [Gtk::Stock::OPEN, Gtk::ResponseType::ACCEPT],
      [Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL]
    ]
  )
  dialog.add_filter(create_filter("CSV files", "*.csv"))
  dialog.set_default_response(Gtk::ResponseType::ACCEPT)

  response = dialog.run
  file_path = dialog.filename
  dialog.destroy

  if response == Gtk::ResponseType::ACCEPT && File.exist?(file_path)
    file_path
  else
    nil
  end
end


def create_filter(name, pattern)
  filter = Gtk::FileFilter.new
  filter.name = name
  filter.add_pattern(pattern)
  filter
end


file_path = select_file
if file_path.nil?
  puts "CSV file not selected or does not exist."
  exit
end


data = load_data(file_path)

max_collaboration_pair = nil
max_collaboration_duration = 0
common_projects = Hash.new { |hash, key| hash[key] = [] }


data.combination(2).each do |proj1, proj2|
  next if proj1[1] != proj2[1]
  
  overlap = overlap_days([proj1[2], proj1[3]], [proj2[2], proj2[3]])
  if overlap > max_collaboration_duration
    max_collaboration_duration = overlap
    max_collaboration_pair = [proj1[0], proj2[0]].sort
    common_projects[proj1[1]] = overlap
  elsif overlap == max_collaboration_duration
    common_projects[proj1[1]] = overlap
  end
end


app = Gtk::Application.new('org.example', :flags_none)


app.signal_connect('activate') do
  window = Gtk::ApplicationWindow.new(app)
  window.set_title("Common projects of the pair with most days worked tohether")
  window.set_default_size(960, 480)
  window.set_position(Gtk::WindowPosition::CENTER)

  list_store = Gtk::ListStore.new(Integer, Integer, Integer, Integer)
  list_store.set_column_types(Integer, Integer, Integer, Integer)

  
  common_projects.each do |project, days_worked|
    iter = list_store.append
    iter[0] = max_collaboration_pair[0] 
    iter[1] = max_collaboration_pair[1]
    iter[2] = project 
    iter[3] = days_worked
  end

  tree_view = Gtk::TreeView.new(list_store)

  ['Employee ID #1', 'Employee ID #2', 'Project ID', 'Days worked'].each_with_index do |title, index|
    renderer = Gtk::CellRendererText.new
    column = Gtk::TreeViewColumn.new(title, renderer, text: index)
    tree_view.append_column(column)
  end

  scrolled_window = Gtk::ScrolledWindow.new
  scrolled_window.set_policy(Gtk::PolicyType::AUTOMATIC, Gtk::PolicyType::AUTOMATIC)
  scrolled_window.add(tree_view)

  window.add(scrolled_window)
  window.show_all
end

app.run([])