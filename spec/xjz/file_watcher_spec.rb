require 'fileutils'

RSpec.describe Xjz::FileWatcher, stub_config: true do
  let(:dir) { File.join($root, 'tmp/fw_test') }
  describe 'start' do
    before :each do |exp|
      `rm -rf #{dir}/*`
      stub_const('Xjz::FileWatcher::INTERVAL', 0.1)
      data = $config.data.dup
      allow($config).to receive(:data).and_return(data)
      data['projects_dir'] = dir
      FileUtils.mkdir_p(dir)
      subject.start
    end

    after :each do
      subject.stop
    end

    it 'should watch file change and call callback' do
      pdir1 = "#{dir}/p1"
      pdir2 = "#{dir}/p2"
      expect(subject).to receive(:on_project_file_change).with("#{pdir1}/a.yml", :created)
      expect(subject).to receive(:on_project_file_change).with("#{pdir1}/b.yml", :created)
      expect(subject).to receive(:on_project_file_change).with("#{pdir2}/aa.yml", :created)
      expect(subject).to receive(:on_project_file_change).with("#{pdir1}/a.yml", :updated)
      expect(subject).to receive(:on_project_file_change).with("#{pdir2}/aa.yml", :deleted)

      `mkdir #{pdir1} #{pdir2}`
      `touch #{pdir1}/a.yml #{pdir1}/b.yml #{pdir2}/aa.yml`
      sleep 0.1
      `touch #{pdir1}/a.yml; rm #{pdir2}/aa.yml`
      sleep 0.2
    end

    it 'should add project when add new project dir' do
      pdir = "#{dir}/p1"
      expect($config.shared_data.app.webui).to receive(:emit_message) \
        .with('project.add', path: pdir)
      `mkdir #{pdir}; touch #{pdir}/a.yml`
      sleep 0.2
    end

    it 'should reload project when update project dir' do
      pdir = "#{dir}/p1"

      expect($config.shared_data.app.webui).to receive(:emit_message) \
        .with('project.add', path: pdir).and_call_original
      `mkdir #{pdir}; touch #{pdir}/a.yml`
      sleep 0.15

      ap = $config.data['.api_projects'].last

      expect($config.shared_data.app.webui).to receive(:emit_message) \
        .with('project.reload', ap: ap).and_call_original
      `touch #{pdir}/a.yml`
      sleep 0.15

      expect($config.shared_data.app.webui).to receive(:emit_message) \
        .with('project.reload', ap: ap).and_call_original
      `touch #{pdir}/b.yml`
      sleep 0.15
    end

    it 'should remove project when remove all yml files of project' do
      pdir = "#{dir}/p1"

      `mkdir #{pdir}; touch #{pdir}/a.yml #{pdir}/b.yml`
      sleep 0.15

      ap = $config.data['.api_projects'].last

      expect {
        `rm #{pdir}/b.yml`
        sleep 0.15
      }.to_not change($config.data['.api_projects'], :size)

      expect($config.shared_data.app.webui).to receive(:emit_message) \
        .with('project.del', ap: ap)
      expect {
        `rm #{pdir}/a.yml`
        sleep 0.15
      }.to_not change($config.data['.api_projects'], :size)
    end
  end
end
