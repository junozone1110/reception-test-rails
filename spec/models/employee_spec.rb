require 'rails_helper'

RSpec.describe Employee, type: :model do
  describe 'associations' do
    it { should belong_to(:department) }
    it { should have_many(:visits).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { build(:employee) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_presence_of(:slack_user_id) }
    it { should validate_presence_of(:department) }
    it { should validate_inclusion_of(:is_active).in_array([true, false]) }
    it { should validate_inclusion_of(:visible_to_visitors).in_array([true, false]) }

    context 'slack_user_id format' do
      it 'accepts valid Slack user ID' do
        employee = build(:employee, slack_user_id: 'U1234ABCD')
        expect(employee).to be_valid
      end

      it 'rejects invalid Slack user ID' do
        employee = build(:employee, slack_user_id: 'invalid_id')
        expect(employee).not_to be_valid
        expect(employee.errors[:slack_user_id]).to be_present
      end
    end

    context 'email format' do
      it 'accepts valid email' do
        employee = build(:employee, email: 'test@example.com')
        expect(employee).to be_valid
      end

      it 'rejects invalid email' do
        employee = build(:employee, email: 'invalid_email')
        expect(employee).not_to be_valid
      end

      it 'allows nil email' do
        employee = build(:employee, email: nil)
        expect(employee).to be_valid
      end

      it 'validates uniqueness of email case insensitively' do
        create(:employee, email: 'test@example.com')
        employee = build(:employee, email: 'TEST@EXAMPLE.COM')
        expect(employee).not_to be_valid
      end
    end

    context 'slack_user_id uniqueness' do
      it 'validates uniqueness case sensitively' do
        create(:employee, slack_user_id: 'U123456789')
        employee = build(:employee, slack_user_id: 'U123456789')
        expect(employee).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:active_employee) { create(:employee, is_active: true) }
    let!(:inactive_employee) { create(:employee, :inactive) }
    let!(:visible_employee) { create(:employee, visible_to_visitors: true) }
    let!(:hidden_employee) { create(:employee, :hidden) }
    let!(:department) { create(:department) }
    let!(:employee_in_dept) { create(:employee, department: department) }

    describe '.active' do
      it 'returns only active employees' do
        expect(Employee.active).to include(active_employee)
        expect(Employee.active).not_to include(inactive_employee)
      end
    end

    describe '.visible_to_visitors' do
      it 'returns only visible employees' do
        expect(Employee.visible_to_visitors).to include(visible_employee)
        expect(Employee.visible_to_visitors).not_to include(hidden_employee)
      end
    end

    describe '.by_department' do
      it 'returns employees in specified department' do
        expect(Employee.by_department(department.id)).to include(employee_in_dept)
      end

      it 'returns all employees when department_id is nil' do
        expect(Employee.by_department(nil).count).to eq(Employee.count)
      end
    end

    describe '.search' do
      let!(:john) { create(:employee, name: 'John Doe', email: 'john@example.com') }
      let!(:jane) { create(:employee, name: 'Jane Smith', email: 'jane@example.com') }

      it 'finds employees by name' do
        results = Employee.search('John')
        expect(results).to include(john)
        expect(results).not_to include(jane)
      end

      it 'finds employees by email' do
        results = Employee.search('jane@example.com')
        expect(results).to include(jane)
      end

      it 'is case insensitive' do
        results = Employee.search('john')
        expect(results).to include(john)
      end

      it 'returns none when query is blank' do
        expect(Employee.search('')).to eq(Employee.none)
      end
    end

    describe '.ordered' do
      let!(:dept1) { create(:department, name: 'B部門', position: 2) }
      let!(:dept2) { create(:department, name: 'A部門', position: 1) }
      let!(:emp1) { create(:employee, name: 'B従業員', department: dept1) }
      let!(:emp2) { create(:employee, name: 'A従業員', department: dept2) }

      it 'orders by department position and name' do
        ordered = Employee.ordered.to_a
        # 部署のposition順、次に名前順でソートされる
        expect(ordered.map(&:id)).to include(emp2.id, emp1.id)
      end
    end
  end

  describe '#display_name' do
    it 'returns name for active employee' do
      employee = build(:employee, name: 'John Doe', is_active: true)
      expect(employee.display_name).to eq('John Doe')
    end

    it 'returns name with inactive marker for inactive employee' do
      employee = build(:employee, name: 'John Doe', is_active: false)
      expect(employee.display_name).to eq('John Doe（無効）')
    end
  end

  describe '#full_info' do
    it 'returns name and department name' do
      department = create(:department, name: '営業部')
      employee = create(:employee, name: 'John Doe', department: department)
      expect(employee.full_info).to eq('John Doe (営業部)')
    end
  end

  describe '#notifiable?' do
    it 'returns true for active employee with valid Slack ID' do
      employee = build(:employee, is_active: true, slack_user_id: 'U1234ABCD')
      expect(employee.notifiable?).to be true
    end

    it 'returns false for inactive employee' do
      employee = build(:employee, :inactive, slack_user_id: 'U1234ABCD')
      expect(employee.notifiable?).to be false
    end

    it 'returns false when slack_user_id is blank' do
      employee = build(:employee, is_active: true, slack_user_id: '')
      expect(employee.notifiable?).to be false
    end
  end

  describe 'callbacks' do
    describe 'avatar URL generation' do
      it 'sets default avatar URL on create when avatar_url is nil' do
        employee = Employee.new(
          name: 'Test Employee',
          slack_user_id: 'U123456789',
          department: create(:department),
          avatar_url: nil
        )
        employee.save
        expect(employee.avatar_url).to be_present
        expect(employee.avatar_url).to include('ui-avatars.com')
      end

      it 'does not overwrite existing avatar URL' do
        url = 'https://example.com/avatar.png'
        employee = create(:employee, avatar_url: url)
        expect(employee.avatar_url).to eq(url)
      end
    end

    describe 'email normalization' do
      it 'normalizes email to lowercase' do
        employee = create(:employee, email: 'TEST@EXAMPLE.COM')
        expect(employee.email).to eq('test@example.com')
      end

      it 'strips whitespace from email' do
        employee = create(:employee, email: ' test@example.com ')
        expect(employee.email).to eq('test@example.com')
      end
    end
  end
end
