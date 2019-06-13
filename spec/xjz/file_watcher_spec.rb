require 'fileutils'

RSpec.describe Xjz::FileWatcher, stub_config: true do
  let(:dir) { File.join($root, 'tmp/fw_test') }

  def touch(files)
    files.each { |path| File.write(path, '') }
  end

  describe 'start' do
    before :each do |exp|
      $config['.edition'] = 'pro'
      Dir["#{dir}/*"].each { |f| FileUtils.rm_rf(f) }
      stub_const('Xjz::FileWatcher::INTERVAL', 0.1)
      data = $config.data.dup
      allow($config).to receive(:data).and_return(data)
      data['projects_dir'] = dir
      FileUtils.mkdir_p(dir)
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

      subject.start
      sleep 0.1

      [pdir1, pdir2].each { |dir| FileUtils.mkdir(dir) }
      touch ["#{pdir1}/a.yml", "#{pdir1}/b.yml", "#{pdir2}/aa.yml"]
      sleep 0.1
      touch ["#{pdir1}/a.yml"]
      FileUtils.rm "#{pdir2}/aa.yml"
      sleep 0.2
    end

    it 'should add project when add new project dir' do
      $config['.api_projects'] = []
      pdir = "#{dir}/p1"
      pdir2 = "#{dir}/p2"
      pdir3 = "#{dir}/p3"
      webui = $config.shared_data.app.webui
      expect(webui).to receive(:emit_message).with('project.add', path: pdir).and_call_original
      expect(webui).to receive(:emit_message).with('project.add', path: pdir2).and_call_original
      expect(webui).to receive(:emit_message).with('project.add', path: pdir3).and_call_original

      subject.start
      sleep 0.1

      [pdir, pdir2, pdir3].each { |dir| FileUtils.mkdir dir }
      touch ["#{pdir}/a.yml", "#{pdir2}/a.yml", "#{pdir3}/b.yml"]
      sleep 0.2
    end

    it 'should not add project for free edition if projects > 0' do
      $config['.edition'] = nil
      $config['.api_projects'] = []
      pdir = "#{dir}/p1"
      pdir2 = "#{dir}/p2"
      dirs = [pdir, pdir2]

      allow($config.shared_data.app.webui).to receive(:emit_message) do |e, path: nil|
        expect(e).to eql('project.add')
        dirs.delete(path)
        $config['.api_projects'] << double('ap', repo_path: path)
      end

      subject.start
      sleep 0.1

      [pdir, pdir2].each { |dir| FileUtils.mkdir dir }
      touch ["#{pdir}/a.yml","#{pdir2}/a.yml"]
      sleep 0.2
      expect($config['.api_projects'].count).to eql(1)
      expect(dirs.length).to eql(1)
    end

    it 'should reload project when update project dir' do
      pdir = "#{dir}/p1"
      FileUtils.mkdir(pdir)
      subject.start
      sleep 0.1

      expect($config.shared_data.app.webui).to receive(:emit_message) \
        .with('project.add', path: pdir).and_call_original
      touch ["#{pdir}/a.yml"]
      sleep 0.15

      ap = $config.data['.api_projects'].last

      expect($config.shared_data.app.webui).to receive(:emit_message) \
        .with('project.reload', ap: ap).and_call_original
      touch ["#{pdir}/a.yml"]
      sleep 0.15

      expect($config.shared_data.app.webui).to receive(:emit_message) \
        .with('project.reload', ap: ap).and_call_original
      touch ["#{pdir}/b.yml"]
      sleep 0.15
    end

    it 'should remove project when remove all yml files of project' do
      pdir = "#{dir}/p1"
      FileUtils.mkdir(pdir)

      subject.start
      sleep 0.1

      touch ["#{pdir}/a.yml", "#{pdir}/b.yml"]
      sleep 0.15

      ap = $config.data['.api_projects'].last

      expect {
        FileUtils.rm "#{pdir}/b.yml"
        sleep 0.15
      }.to_not change($config.data['.api_projects'], :size)

      expect($config.shared_data.app.webui).to receive(:emit_message) \
        .with('project.del', ap: ap)
      expect {
        FileUtils.rm "#{pdir}/a.yml"
        sleep 0.15
      }.to_not change($config.data['.api_projects'], :size)
    end
  end
end
