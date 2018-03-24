def apply_db_time_now
  allow(QS::Adapters::Orm.instance).to receive(:now).and_return(Time.zone.now)
end
