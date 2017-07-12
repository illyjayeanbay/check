class RsvpsController < ApplicationController
  include ApplicationHelper
  include RsvpsHelper
  include PeopleHelper

  before_filter :has_current_site_and_event
  before_filter :get_event
  before_filter :is_owner, only: [:show]

  def index
    @syncing = false
    if @current_event.sync_status == 'pending'
      @syncing = true
    else

      if params[:query]
        r = Rsvp.where(event_id: @current_event.id, host_id: nil)
        @rsvps = r.joins(:person).where('lower(first_name) LIKE ? OR lower(last_name) LIKE ? OR lower(email) LIKE ?', "%#{params[:query].downcase}%", "%#{params[:query].downcase}%", "%#{params[:query].downcase}%")
      else
        @rsvps = Rsvp.where(event_id: @current_event.id, host_id: nil)
      end

      @letters = []
      @rsvps.each { |rsvp| @letters << rsvp.person.last_name[0].upcase.strip unless rsvp.person.nil? }
      @letters.sort_by!(&:downcase) unless @letters.empty?
      @letters.uniq!
      get_count
      @rsvps.order('last_name DESC') unless @rsvps.empty?
      render layout: false if params[:query]
    end
  end

  def new
    @page = 'new-rsvp'
    @rsvp = Rsvp.new
    @person = Person.new
    @host = Rsvp.find(params[:host_id]) if params[:host_id]
    @event = if params[:event_id]
               Event.find(params[:event_id])
             else
               @current_event
             end
   render layout: false
  end

  def create
    @rsvp = Rsvp.new(rsvp_params)
    if @rsvp.save
      @person = Person.find_or_create_by(email: rsvp_params[:email], nation_id: @rsvp.nation_id)
      if @host && @event
        @rsvp.update_attributes(person_id: @person.id, nation_id: @current_event.nation_id, guests_count: 0, host_id: @host.id, event_id: @event.id)
      else
        @rsvp.update_attributes(person_id: @person.id, nation_id: @current_event.nation_id, guests_count: 0)
      end

    end
    redirect_to rsvps_path
  end

  def cache
    # create_cache
    # redirect_to rsvps_path
    @current_event.update_attributes(sync_status: 'pending', sync_percent: 0, sync_date: DateTime.now)
    Resque.enqueue(Sync, params[:id], session[:current_site], session[:credential_id])

    respond_to do |format|
      format.json { render json: { status: 'started' } }
    end
  end

  def show
    @rsvp = Rsvp.find(params[:id])
    # check_nb_update(Rsvp.find(params[:id]).person)
    @add_guests = add_guests(@rsvp)
    @guests = Rsvp.where(host_id: @rsvp.id)
    render layout: false
  end

  def check_in
    @rsvp = Rsvp.find(params[:id])
    @rsvp.update_attributes(attended: true)
    nationbuilder_rsvp = send_rsvp_to_nationbuilder(@rsvp, @rsvp.person)
    if nationbuilder_rsvp[:status]
      respond_to do |format|
        format.js {}
      end
    end
  end

  def check_out
    @rsvp = Rsvp.find(params[:id])
    @rsvp.update_attributes(attended: false)
    nationbuilder_rsvp = send_rsvp_to_nationbuilder(@rsvp, @rsvp.person)
    if nationbuilder_rsvp[:status]
      respond_to do |format|
        format.js {}
      end
    end
  end

  def sync
    site = session[:current_site]
    Rsvp.sync(@current_event, site)
    respond_to do |format|
      format.js {}
    end
  end

  private

  def rsvp_params
    params.require(:rsvp).permit(:event_id, :guests_count, :canceled, :attended, :rsvpNBID, :nation_id, :volunteer, :is_private, :shift_ids, :host_id, :person_id, :ticket_type, :tickets_sold, :person, person_attributes: %i[first_name last_name email phone_number])
  end

  def has_current_site_and_event
    if session[:current_site]
      if session[:current_event]
        true
      else
        redirect_to choose_event_path
      end
    else
      redirect_to choose_site_path
    end
  end

  def is_owner
    if current_user.nation.id != Rsvp.find(params[:id]).person.nation_id
      begin
        redirect_to(:back, flash: { error: "Sorry, you don't have access to this information" })
      rescue ActionController::RedirectBackError
        redirect_to(:root, flash: { error: "Sorry, you don't have access to this information" })
      end
    end
  end
end
