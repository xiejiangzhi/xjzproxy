module Support
  module TimeHelper
    def travel_to(time)
      allow(Time).to receive(:now).and_return(time)
    end

    def travel_back
      allow(Time).to receive(:now).and_call_original
    end
  end
end
